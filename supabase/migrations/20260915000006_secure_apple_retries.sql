begin;

alter table public.apple_revocation_queue drop constraint apple_revocation_queue_status_check;
alter table public.apple_revocation_queue add constraint apple_revocation_queue_status_check
  check (status in ('pending','in_progress','retry_pending','retrying','needs_authorization','outcome_unknown','completed'));
alter table public.apple_revocation_queue
  add column next_attempt_at timestamptz,
  add column lease_id uuid,
  add column lease_expires_at timestamptz;
-- Legacy pending did not distinguish an active first attempt from a failure.
update public.apple_revocation_queue set status='outcome_unknown' where status='pending';

create table public.apple_revocation_worker_nonces (
  nonce_hash bytea primary key,
  expires_at timestamptz not null
);
alter table public.apple_revocation_worker_nonces enable row level security;
revoke all on public.apple_revocation_worker_nonces from public, anon, authenticated, service_role;

-- Only cron's postgres owner may mint a one-use invocation. No API/server key
-- enters SQL text, Vault, pg_net headers, or query output.
create function public.enqueue_apple_revocation_retry() returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  invocation_nonce text := pg_catalog.encode(extensions.gen_random_bytes(32), 'hex');
  request_id bigint;
begin
  -- Managed pg_net objects may require Supabase Support to revoke their grants.
  -- Never enqueue even a one-use nonce until the actual ACL is restricted.
  if has_table_privilege('anon','net.http_request_queue','SELECT')
     or has_table_privilege('authenticated','net.http_request_queue','SELECT')
     or has_table_privilege('anon','net._http_response','SELECT')
     or has_table_privilege('authenticated','net._http_response','SELECT') then
    raise exception 'pg_net permissions not restricted';
  end if;
  delete from public.apple_revocation_worker_nonces where expires_at <= now();
  insert into public.apple_revocation_worker_nonces(nonce_hash, expires_at)
  values (extensions.digest(invocation_nonce, 'sha256'), now() + interval '5 minutes');
  select net.http_post(
    url := 'https://ebxdbadcejbytixumxrj.supabase.co/functions/v1/account-delete',
    headers := jsonb_build_object('Content-Type','application/json','x-scoor-retry-nonce',invocation_nonce),
    body := '{}'::jsonb, timeout_milliseconds := 120000
  ) into request_id;
  return request_id;
end;
$$;
revoke all on function public.enqueue_apple_revocation_retry() from public, anon, authenticated, service_role;

-- Consume authentication and claim rows atomically. Replay, invalid and expired
-- nonces cannot claim work. Row locks + leases prevent overlapping execution.
create function public.claim_apple_revocation_retries(p_nonce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  accepted bytea;
  items jsonb;
begin
  if p_nonce is null or p_nonce !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('authorized',false,'items','[]'::jsonb);
  end if;
  delete from public.apple_revocation_worker_nonces
  where nonce_hash=extensions.digest(p_nonce,'sha256') and expires_at > now()
  returning nonce_hash into accepted;
  if accepted is null then
    return jsonb_build_object('authorized',false,'items','[]'::jsonb);
  end if;
  -- Do not interpret an interrupted call as a confirmed Apple failure.
  update public.apple_revocation_queue
    set status='outcome_unknown', lease_id=null, lease_expires_at=null
    where (status in ('pending','in_progress') and created_at < now()-interval '5 minutes')
       or (status='retrying' and lease_expires_at <= now());
  with candidates as (
    select id from public.apple_revocation_queue
    where status='retry_pending' and refresh_token is not null
      and next_attempt_at <= now()
    order by next_attempt_at, created_at, id
    for update skip locked limit 10
  ), claimed as (
    update public.apple_revocation_queue q
    set status='retrying', lease_id=gen_random_uuid(),
        lease_expires_at=now()+interval '5 minutes',
        attempts=q.attempts+1, last_attempt_at=now()
    from candidates c where q.id=c.id
    returning q.id,q.refresh_token,q.lease_id
  ) select coalesce(jsonb_agg(to_jsonb(claimed)), '[]'::jsonb) into items from claimed;
  return jsonb_build_object('authorized',true,'items',items);
end;
$$;
revoke all on function public.claim_apple_revocation_retries(text) from public, anon, authenticated;
grant execute on function public.claim_apple_revocation_retries(text) to service_role;

create function public.finish_apple_revocation_retry(p_id uuid, p_lease uuid, p_success boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
declare affected integer;
begin
  if p_success then
    delete from public.apple_revocation_queue
      where id=p_id and status='retrying' and lease_id=p_lease and lease_expires_at > now();
  else
    update public.apple_revocation_queue
      set status='retry_pending', next_attempt_at=now()+interval '1 hour', lease_id=null, lease_expires_at=null
      where id=p_id and status='retrying' and lease_id=p_lease and lease_expires_at > now();
  end if;
  get diagnostics affected = row_count;
  return affected=1;
end;
$$;
revoke all on function public.finish_apple_revocation_retry(uuid,uuid,boolean) from public, anon, authenticated;
grant execute on function public.finish_apple_revocation_retry(uuid,uuid,boolean) to service_role;

commit;
