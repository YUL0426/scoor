-- Isolated PostgreSQL/Supabase test database only. Rolls all fixtures back.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values('b1000000-0000-4000-8000-000000000001'),('b2000000-0000-4000-8000-000000000002');
insert into topics(id,category,title) values('b3000000-0000-4000-8000-000000000003','tech','Consent fixture');
create function pg_temp.expect_denied(statement text, expected text default '42501') returns void language plpgsql as $$
begin
 begin execute statement;
 exception when others then
  if sqlstate=expected then return; end if;
  raise;
 end;
 raise exception 'Unexpected permission: %', statement;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
do $$ begin assert not public.has_required_consent(); assert not public.has_publication_consent(); end $$;
select pg_temp.expect_denied($q$insert into scores(user_id,day,value,client_updated_at) values(auth.uid(),current_date,50,now())$q$);
select pg_temp.expect_denied($q$insert into legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language) values(auth.uid(),'terms','2026-09-15.1','forged',true,gen_random_uuid(),'en')$q$);
select pg_temp.expect_denied($q$select public.accept_required_consent('old','wrong',gen_random_uuid(),'ko')$q$,'22023');
select pg_temp.expect_denied($q$select public.accept_publication_consent('2.0','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',gen_random_uuid(),'ko')$q$);
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e','b4000000-0000-4000-8000-000000000004','ko');
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e','b4000000-0000-4000-8000-000000000004','ko');
do $$ begin
 assert public.has_required_consent(); assert public.has_publication_consent();
 assert (select count(*)=4 from legal_consent_events);
 assert (select bool_and(recorded_at is not null and language='ko') from legal_consent_events);
end $$;
insert into scores(user_id,day,value,client_updated_at) values(auth.uid(),current_date,50,now());
insert into posts(id,author_id,score,message,primary_mood) values('b6000000-0000-4000-8000-000000000006',auth.uid(),50,'fixture','calm');
insert into comments(post_id,author_id,text) values('b6000000-0000-4000-8000-000000000006',auth.uid(),'test');
insert into world_scores(user_id,topic_id,target_id,value) values(auth.uid(),'b3000000-0000-4000-8000-000000000003','general',50);
select submit_topic_proposal('b7000000-0000-4000-8000-000000000007','Fixture topic','Test-only submission','tech','discussion',null,'Low','High');
select public.withdraw_required_consent(gen_random_uuid());
do $$ begin assert not public.has_required_consent(); end $$;
select pg_temp.expect_denied($q$update scores set value=90 where user_id=auth.uid()$q$);
select pg_temp.expect_denied($q$update posts set deleted_at=now(),message='smuggled' where author_id=auth.uid()$q$);
update posts set deleted_at=now() where author_id=auth.uid();
delete from comments where author_id=auth.uid();
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e','b4000000-0000-4000-8000-000000000004','ko');
do $$ begin assert not public.has_required_consent(), 'Replayed request undid withdrawal'; end $$;
select set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000002',true);
do $$ begin assert not public.has_required_consent(); assert (select count(*)=0 from legal_consent_events), 'Other account receipts leaked'; end $$;
select pg_temp.expect_denied($q$select public.legal_current_for('b1000000-0000-4000-8000-000000000001','terms','2026-09-15.1')$q$);
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',gen_random_uuid(),'ko');
do $$ begin assert public.has_required_consent(); assert public.has_publication_consent(); end $$;
-- Legacy publication withdrawal must not silently grant the license again.
select public.withdraw_publication_consent(gen_random_uuid());
do $$ begin assert not public.has_required_consent(); assert not public.has_publication_consent(); end $$;
select public.accept_required_consent('2026-09-15.1','8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e',gen_random_uuid(),'ko');
do $$ begin assert public.has_required_consent(); assert public.has_publication_consent(); end $$;
reset role;
rollback;
\echo LEGAL_CONSENT_TESTS_PASSED
