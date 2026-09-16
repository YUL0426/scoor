-- Run inside a transaction and roll back. No real user/account fixtures.
do $test$
declare
  nonce text;
  result jsonb;
  second_result jsonb;
  row_id uuid;
  row_lease uuid;
  request_id bigint;
  result_count integer;
  finished boolean;
  expect_net_block boolean := coalesce(current_setting('scoor.test.expect_net_block',true),'false')='true';
begin
  if exists(select 1 from public.apple_revocation_queue) then
    raise exception 'Run this test only against an empty retry queue';
  end if;
  if has_table_privilege('service_role','public.apple_revocation_worker_nonces','SELECT')
     or has_function_privilege('anon','public.claim_apple_revocation_retries(text)','EXECUTE')
     or has_function_privilege('authenticated','public.enqueue_apple_revocation_retry()','EXECUTE') then
    raise exception 'Queue / nonce permissions are not restricted';
  end if;

  -- This network request is rolled back, so pg_net never sends it.
  if expect_net_block then
    begin
      perform public.enqueue_apple_revocation_retry();
      raise exception 'Unsafe queue accepted an invocation';
    exception when raise_exception then
      if sqlerrm <> 'pg_net permissions not restricted' then raise; end if;
    end;
    if exists(select 1 from public.apple_revocation_worker_nonces) then
      raise exception 'Blocked enqueue persisted a nonce';
    end if;
    nonce := encode(extensions.gen_random_bytes(32),'hex');
    insert into public.apple_revocation_worker_nonces values(extensions.digest(nonce,'sha256'),now()+interval '5 minutes');
  else
    request_id := public.enqueue_apple_revocation_retry();
    select headers->>'x-scoor-retry-nonce' into nonce from net.http_request_queue where id=request_id;
    if nonce is null or length(nonce) <> 64 or exists (
      select 1 from net.http_request_queue where id=request_id
        and (headers ? 'apikey' or headers ? 'Authorization' or headers::text like '%sb_secret_%')
    ) then raise exception 'Unexpected credential in outgoing request'; end if;
  end if;

  insert into public.apple_revocation_queue(refresh_token,status,next_attempt_at,attempts)
    select 'synthetic-retry-'||g,'retry_pending',now()-interval '1 minute',1 from generate_series(1,11) g;
  insert into public.apple_revocation_queue(refresh_token,status,next_attempt_at) values
    ('synthetic-initial','in_progress',now()-interval '1 minute'),
    ('synthetic-future','retry_pending',now()+interval '1 hour'),
    (null,'needs_authorization',null),
    ('synthetic-legacy','pending',now()-interval '1 minute');
  insert into public.apple_revocation_queue(refresh_token,status,created_at,lease_id,lease_expires_at) values
    ('synthetic-interrupted-initial','in_progress',now()-interval '10 minutes',null,null),
    ('synthetic-interrupted-retry','retrying',now()-interval '10 minutes',gen_random_uuid(),now()-interval '1 minute');

  result := public.claim_apple_revocation_retries(nonce);
  if result->>'authorized' <> 'true' or jsonb_array_length(result->'items') <> 10 then
    raise exception 'Expected exactly ten retry claims';
  end if;
  if exists(select 1 from jsonb_array_elements(result->'items') item
    where item->>'refresh_token' not like 'synthetic-retry-%') then
    raise exception 'Claim included an initial, future or unresolved attempt';
  end if;
  second_result := public.claim_apple_revocation_retries(nonce);
  if second_result->>'authorized' <> 'false' then raise exception 'Nonce replay accepted'; end if;
  if (select count(*) from public.apple_revocation_queue where status='outcome_unknown') <> 2 then
    raise exception 'Interrupted calls were not quarantined';
  end if;

  row_id := (result->'items'->0->>'id')::uuid;
  row_lease := (result->'items'->0->>'lease_id')::uuid;
  if public.finish_apple_revocation_retry(row_id,gen_random_uuid(),true) then
    raise exception 'Wrong lease completed a retry';
  end if;
  if not public.finish_apple_revocation_retry(row_id,row_lease,false) then
    raise exception 'Could not record confirmed failure';
  end if;
  if not exists(select 1 from public.apple_revocation_queue where id=row_id and status='retry_pending' and next_attempt_at > now()) then
    raise exception 'Failed retry has no backoff';
  end if;
  if public.finish_apple_revocation_retry(row_id,row_lease,true) then
    raise exception 'Reused lease completed a retry';
  end if;
  row_id := (result->'items'->1->>'id')::uuid;
  row_lease := (result->'items'->1->>'lease_id')::uuid;
  finished := public.finish_apple_revocation_retry(row_id,row_lease,true);
  if not finished or exists(select 1 from public.apple_revocation_queue where id=row_id) then
    raise exception 'Successful retry did not remove its token';
  end if;

  nonce := encode(extensions.gen_random_bytes(32),'hex');
  insert into public.apple_revocation_worker_nonces values(extensions.digest(nonce,'sha256'),now()+interval '5 minutes');
  second_result := public.claim_apple_revocation_retries(nonce);
  if jsonb_array_length(second_result->'items') <> 1 then
    raise exception 'Second worker claimed leased rows or ignored backoff';
  end if;
  nonce := encode(extensions.gen_random_bytes(32),'hex');
  insert into public.apple_revocation_worker_nonces values(extensions.digest(nonce,'sha256'),now()-interval '1 second');
  if public.claim_apple_revocation_retries(nonce)->>'authorized' <> 'false'
     or public.claim_apple_revocation_retries(repeat('0',64))->>'authorized' <> 'false' then
    raise exception 'Expired or unknown nonce accepted';
  end if;
end;
$test$;
select 'APPLE_RETRY_SECURITY_TESTS_PASSED' as result;
