-- Isolated database only: all fixtures roll back.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values('d9000000-0000-4000-8000-000000000009');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','d9000000-0000-4000-8000-000000000009',true);
do $$
declare lang text; request uuid;
begin
 foreach lang in array array['ja','fr','pt-BR'] loop
  request := gen_random_uuid();
  perform public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',request,lang,'apple');
  perform public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',request,lang,'apple');
  assert public.has_required_consent();
  assert (select count(*)=2 from public.legal_consent_events where user_id=auth.uid() and request_id=request and language=lang);
  assert not public.has_sensitive_consent();
  perform public.withdraw_required_consent(gen_random_uuid());
  assert not public.has_required_consent();
 end loop;
 assert not exists(select 1 from public.legal_consent_events where user_id=auth.uid() and kind not in ('terms','age','publication'));
 begin
  perform public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',gen_random_uuid(),'unrecognized','apple');
  raise exception 'Unexpected acceptance of unsupported language';
 exception when invalid_parameter_value then null;
 end;
end $$;
rollback;
