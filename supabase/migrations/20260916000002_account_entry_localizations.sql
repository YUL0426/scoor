-- Translations of the unchanged 2026-09-16.1 policy. No new consent purposes.
begin;
alter table public.legal_consent_events drop constraint legal_consent_events_language_check;
alter table public.legal_consent_events add constraint legal_consent_events_language_check
 check(language in ('ko','en','ja','fr','pt-BR','legacy'));

create or replace function public.accept_account_terms(p_version text,p_digest text,p_request_id uuid,p_language text,p_action text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_version is distinct from '2026-09-16.1'
 or p_digest is distinct from '67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11'
 or p_language is null or p_language not in ('ko','en','ja','fr','pt-BR') or p_request_id is null
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


commit;
