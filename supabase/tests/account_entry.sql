-- Run against an isolated database. Fixtures and test data are rolled back.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values('d1000000-0000-4000-8000-000000000001'),('d2000000-0000-4000-8000-000000000002');
insert into topics(id,category,title) values
 ('d3000000-0000-4000-8000-000000000003','tech','Ordinary entry test'),
 ('d4000000-0000-4000-8000-000000000004','politics','Sensitive entry test');
create function pg_temp.denied(statement text) returns void language plpgsql as $$
begin
 begin execute statement;
 exception when others then if sqlstate in ('42501','22023') then return; end if; raise; end;
 raise exception 'Unexpected permission: %',statement;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert not public.has_required_consent();
 assert public.needs_sensitive_consent('d4000000-0000-4000-8000-000000000004');
 assert not public.needs_sensitive_consent('d3000000-0000-4000-8000-000000000003');
end $$;
select pg_temp.denied($q$select public.accept_account_terms('2026-09-16.1','bad',gen_random_uuid(),'ko','apple')$q$);
select pg_temp.denied($q$select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',gen_random_uuid(),'ko','automatic')$q$);
select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11','d5000000-0000-4000-8000-000000000005','ko','apple');
select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11','d5000000-0000-4000-8000-000000000005','ko','apple');
do $$ begin
 assert public.has_required_consent(); assert public.has_publication_consent();
 assert (select count(*)=2 from legal_consent_events);
 assert (select bool_and(kind in ('terms','age') and acceptance_action='apple') from legal_consent_events);
 assert (select count(*)=0 from sensitive_consent_events);
 assert not public.has_sensitive_consent();
end $$;
insert into scores(user_id,day,value,client_updated_at) values(auth.uid(),current_date,70,now());
insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'d3000000-0000-4000-8000-000000000003','general',70);
select pg_temp.denied($q$insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'d4000000-0000-4000-8000-000000000004','general',70)$q$);
select public.set_sensitive_consent(true,'2026-09-15.1',gen_random_uuid());
do $$ begin assert not public.needs_sensitive_consent('d4000000-0000-4000-8000-000000000004'); end $$;
insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'d4000000-0000-4000-8000-000000000004','general',70);
select public.set_sensitive_consent(false,'2026-09-15.1',gen_random_uuid());
do $$ begin
 assert public.has_required_consent(), 'Optional withdrawal must not block basic account use';
 assert public.needs_sensitive_consent('d4000000-0000-4000-8000-000000000004');
 assert (select count(*)=0 from world_scores where topic_id='d4000000-0000-4000-8000-000000000004');
end $$;
select public.withdraw_required_consent(gen_random_uuid());
select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11','d5000000-0000-4000-8000-000000000005','ko','apple');
do $$ begin assert not public.has_required_consent(), 'A delayed retry must not undo stopping services'; end $$;
select pg_temp.denied($q$update scores set value=71 where user_id=auth.uid()$q$);
select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',gen_random_uuid(),'ko','continue');
do $$ begin assert public.has_required_consent(); assert not public.has_sensitive_consent(); end $$;
select set_config('request.jwt.claim.sub','d2000000-0000-4000-8000-000000000002',true);
do $$ begin assert not public.has_required_consent(); assert (select count(*)=0 from legal_consent_events); end $$;
select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',gen_random_uuid(),'en','google');
do $$ begin assert public.has_required_consent(); assert (select bool_and(acceptance_action='google') from legal_consent_events); end $$;
reset role;
set local role anon;
select pg_temp.denied($q$select public.accept_account_terms('2026-09-16.1','67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11',gen_random_uuid(),'en','google')$q$);
reset role;
rollback;
\echo ACCOUNT_ENTRY_TESTS_PASSED
