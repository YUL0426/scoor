\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values('c1000000-0000-4000-8000-000000000001');
insert into topics(id,category,title) values('c2000000-0000-4000-8000-000000000002','politics','Political topic');
create function pg_temp.denied(statement text) returns void language plpgsql as $$
begin
 begin execute statement;
 exception when others then if sqlstate in ('42501','22023') then return; end if; raise; end;
 raise exception 'Unexpected permission: %',statement;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',gen_random_uuid(),'en');
select pg_temp.denied($q$insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'c2000000-0000-4000-8000-000000000002','general',70)$q$);
select public.set_sensitive_consent(true,'2026-09-15.1',gen_random_uuid());
insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'c2000000-0000-4000-8000-000000000002','general',70);
select public.set_sensitive_consent(false,'2026-09-15.1',gen_random_uuid());
do $$ begin assert not public.has_sensitive_consent(); assert (select count(*)=0 from world_scores where user_id=auth.uid()); end $$;
select pg_temp.denied($q$insert into posts(author_id,score,message,primary_mood) values(auth.uid(),50,'go kill yourself','calm')$q$);
insert into scores(user_id,day,value,reason,mood,client_updated_at) values(auth.uid(),current_date,50,'private text','calm',now());
insert into posts(author_id,score,message,primary_mood,source_day) values(auth.uid(),50,'shared text','calm',current_date);
update scores set deleted_at=now() where user_id=auth.uid();
do $$ begin
 assert (select value=0 and reason is null and mood is null from scores where user_id=auth.uid());
 assert (select deleted_at is not null and message='[deleted]' from posts where author_id=auth.uid());
end $$;
select pg_temp.denied($q$select * from apple_revocation_queue$q$);
select public.withdraw_required_consent(gen_random_uuid());
select pg_temp.denied($q$insert into posts(author_id,score,message,primary_mood) values(auth.uid(),50,'blocked','calm')$q$);
reset role;
rollback;
\echo RELEASE_SAFETY_TESTS_PASSED
