-- The accepted terms already cover content licensing and community rules.
-- Publishing needs no additional agreement. Preserve earlier withdrawals:
-- a newer terms acceptance is needed if publication consent was withdrawn.
begin;
create or replace function public.has_required_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and
 public.legal_current_for(auth.uid(),'terms','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'privacy_notice','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'account_data','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'age','2026-09-13.1') and
 coalesce((select accepted or id < (select max(id) from public.legal_consent_events
   where user_id=auth.uid() and kind='terms' and accepted)
   from public.legal_consent_events where user_id=auth.uid() and kind='publication'
   order by id desc limit 1), true)
$$;
create or replace function public.has_publication_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select public.has_required_consent()
$$;
notify pgrst, 'reload schema';
commit;
