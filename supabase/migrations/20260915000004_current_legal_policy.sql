begin;
create or replace function public.accept_required_consent(p_version text,p_digest text,p_request_id uuid,p_language text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_version is distinct from '2026-09-15.1' or p_digest is distinct from '8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e'
 or p_language not in ('ko','en') or p_language is null or p_request_id is null then
 raise exception 'Unknown consent document' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 select auth.uid(),kind,p_version,p_digest,true,p_request_id,p_language
 from unnest(array['terms','privacy_notice','account_data','age']) kind
 on conflict(user_id,request_id,kind) do nothing;
end $$;

create or replace function public.accept_publication_consent(p_version text,p_digest text,p_request_id uuid,p_language text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found or not public.has_required_consent() then raise exception 'Required consent missing' using errcode='42501'; end if;
 if p_version is distinct from '2.0' or p_digest is distinct from '8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e'
 or p_language not in ('ko','en') or p_language is null or p_request_id is null then
 raise exception 'Unknown publication agreement' using errcode='22023'; end if;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 values(auth.uid(),'publication',p_version,p_digest,true,p_request_id,p_language)
 on conflict(user_id,request_id,kind) do nothing;
 -- A stale retry after withdrawal must not silently restore consent.
 if public.has_publication_consent() then
 insert into public.guideline_acceptances(user_id,version,accepted_at) values(auth.uid(),p_version,clock_timestamp())
 on conflict(user_id) do update set version=excluded.version,accepted_at=excluded.accepted_at;
 end if;
end $$;

create or replace function public.withdraw_required_consent(p_request_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 select auth.uid(),kind,case when kind='publication' then '2.0' else '2026-09-15.1' end,
 '8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',false,p_request_id,coalesce((select language from public.legal_consent_events where user_id=auth.uid() and kind='terms' order by id desc limit 1),'en')
 from unnest(array['terms','privacy_notice','account_data','age','publication']) kind
 on conflict(user_id,request_id,kind) do nothing;
 delete from public.guideline_acceptances where user_id=auth.uid();
end $$;

create or replace function public.withdraw_publication_consent(p_request_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 values(auth.uid(),'publication','2.0','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',false,p_request_id,
 coalesce((select language from public.legal_consent_events where user_id=auth.uid() and kind='terms' order by id desc limit 1),'en'))
 on conflict(user_id,request_id,kind) do nothing;
 delete from public.guideline_acceptances where user_id=auth.uid();
end $$;

create or replace function public.has_required_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and
 public.legal_current_for(auth.uid(),'terms','2026-09-15.1') and
 public.legal_current_for(auth.uid(),'privacy_notice','2026-09-15.1') and
 public.legal_current_for(auth.uid(),'account_data','2026-09-15.1') and
 public.legal_current_for(auth.uid(),'age','2026-09-15.1') and
 coalesce((select accepted or id < (select max(id) from public.legal_consent_events
   where user_id=auth.uid() and kind='terms' and accepted)
   from public.legal_consent_events where user_id=auth.uid() and kind='publication'
   order by id desc limit 1), true)
$$;

notify pgrst,'reload schema';
commit;
