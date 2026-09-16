-- One explicit entry action accepts the terms and asserts signup eligibility.
-- Necessary account processing relies on contract performance. Never manufacture
-- privacy/account-data or sensitive consent receipts from a social login.
begin;
alter table public.legal_consent_events add column acceptance_action text
 check (acceptance_action in ('apple','google','email','continue','account_stop'));

create function public.accept_account_terms(p_version text,p_digest text,p_request_id uuid,p_language text,p_action text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_version is distinct from '2026-09-16.1'
 or p_digest is distinct from '67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11'
 or p_language is null or p_language not in ('ko','en') or p_request_id is null
 or p_action is null or p_action not in ('apple','google','email','continue') then
  raise exception 'Unknown account entry notice' using errcode='22023';
 end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language,acceptance_action)
 select auth.uid(),kind,p_version,p_digest,true,p_request_id,p_language,p_action
 from unnest(array['terms','age']) kind
 on conflict(user_id,request_id,kind) do nothing;
end $$;
revoke all on function public.accept_account_terms(text,text,uuid,text,text) from public,anon;
grant execute on function public.accept_account_terms(text,text,uuid,text,text) to authenticated;

-- Older releases retain their original receipts and withdrawal semantics.
-- A rollout must not force existing accounts to register again or convert their
-- historical data consent into consent to a new purpose.
create or replace function public.has_required_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and not is_banned) and (
  (public.legal_current_for(auth.uid(),'terms','2026-09-16.1') and
   public.legal_current_for(auth.uid(),'age','2026-09-16.1'))
  or
  (public.legal_current_for(auth.uid(),'terms','2026-09-15.1') and
   public.legal_current_for(auth.uid(),'privacy_notice','2026-09-15.1') and
   public.legal_current_for(auth.uid(),'account_data','2026-09-15.1') and
   public.legal_current_for(auth.uid(),'age','2026-09-15.1'))
 ) and coalesce((select accepted or id < (select max(id) from public.legal_consent_events
   where user_id=auth.uid() and kind='terms' and accepted)
   from public.legal_consent_events where user_id=auth.uid() and kind='publication'
   order by id desc limit 1), true)
$$;

-- This RPC remains for old clients; the new UI calls it "Stop account services".
create or replace function public.withdraw_required_consent(p_request_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language,acceptance_action)
 select auth.uid(),kind,'2026-09-16.1',
 '67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',false,p_request_id,
 coalesce((select language from public.legal_consent_events where user_id=auth.uid() and kind='terms' order by id desc limit 1),'en'),
 'account_stop' from unnest(array['terms','age','publication']) kind
 on conflict(user_id,request_id,kind) do nothing;
 delete from public.guideline_acceptances where user_id=auth.uid();
end $$;

-- Check before a client sends score/comment text. The existing submission trigger
-- remains authoritative for direct API calls and a concurrent withdrawal.
create function public.needs_sensitive_consent(p_topic_id uuid)
returns boolean language plpgsql security invoker set search_path=public,pg_temp as $$
declare is_sensitive boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select category='politics' or requires_sensitive_consent into is_sensitive from public.topics where id=p_topic_id;
 if not found then raise exception 'Topic unavailable' using errcode='42501'; end if;
 return is_sensitive and not public.has_sensitive_consent();
end $$;
revoke all on function public.needs_sensitive_consent(uuid) from public,anon;
grant execute on function public.needs_sensitive_consent(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
