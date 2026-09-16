\set ON_ERROR_STOP on
begin;
create or replace function public.topic_assert(ok boolean, label text) returns void language plpgsql as $$ begin
 if ok is distinct from true then raise exception 'FAIL %',label; end if; raise notice 'PASS %',label; end $$;
insert into auth.users(id,email) values ('55555555-5555-5555-5555-555555555555','topic-a@example.invalid'),('66666666-6666-6666-6666-666666666666','topic-b@example.invalid');
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-5555-5555-555555555555';
do $$ begin
 perform public.submit_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','주 4일 근무 찬성하나요?','함께 주 4일 근무의 장단점을 논의해요.','work','discussion','','반대','찬성');
 raise exception 'FAIL consent bypass';
exception when insufficient_privilege then raise notice 'PASS consent required'; end $$;
insert into public.guideline_acceptances(user_id,version) values(auth.uid(),'1.0');
select public.submit_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','주 4일 근무 찬성하나요?','함께 주 4일 근무의 장단점을 논의해요.','work','discussion','','반대','찬성');
select public.submit_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','주 4일 근무 찬성하나요?','함께 주 4일 근무의 장단점을 논의해요.','work','discussion','','반대','찬성');
select public.topic_assert((select count(*)=1 from public.topic_submissions),'retries create one proposal');
select public.topic_assert((select count(*)=0 from public.topics_feed where origin='community'),'pending stays private');
do $$ begin
 update public.topic_submissions set status='approved'; raise exception 'FAIL self approve';
exception when insufficient_privilege then raise notice 'PASS direct update forbidden'; end $$;
do $$ begin
 perform public.review_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',1,'approved','','attacker'); raise exception 'FAIL review RPC exposed';
exception when insufficient_privilege then raise notice 'PASS review RPC forbidden'; end $$;
set local request.jwt.claim.sub='66666666-6666-6666-6666-666666666666';
select public.topic_assert((select count(*)=0 from public.topic_submissions),'other user cannot read proposals');
reset role;
set local role service_role;
select public.review_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',1,'changes_requested','질문을 구체화해 주세요.','operator@example.invalid');
reset role;
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-5555-5555-555555555555';
select public.topic_assert((select count(*)=1 from public.topic_submission_notifications),'review notification created');
do $$ begin
 update public.topic_submission_notifications set title='forged'; raise exception 'FAIL notification forged';
exception when insufficient_privilege then raise notice 'PASS notification content immutable'; end $$;
update public.topic_submission_notifications set read_at=now();
select public.topic_assert((select bool_and(read_at is not null) from public.topic_submission_notifications),'notification read receipt');
select public.submit_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','주 4일 근무 도입에 찬성하나요?','함께 주 4일 근무의 장단점을 논의해요.','work','discussion','','반대','찬성',2);
reset role;
set local role service_role;
do $$ begin
 perform public.review_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',1,'approved','','operator'); raise exception 'FAIL stale approval';
exception when serialization_failure then raise notice 'PASS stale review denied'; end $$;
select public.review_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',3,'approved','','operator');
select public.review_topic_proposal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',3,'approved','','operator');
select public.topic_assert((select count(*)=1 from public.topics where origin='community'),'approval retry creates one topic');
select public.topic_assert((select count(*)=2 from public.topic_submission_notifications),'approval retry creates one notification');
reset role;
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-5555-5555-555555555555';
insert into public.world_scores(user_id,topic_id,target_id,value) select auth.uid(),topic_id,'match',75 from public.topic_submissions where status='approved';
insert into public.reports(reporter_id,target_type,target_id,reason) select auth.uid(),'topic',topic_id,'abuse' from public.topic_submissions where status='approved';
select public.submit_topic_proposal('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','재택근무 도입에 찬성하나요?','재택근무의 장점과 단점을 함께 논의해요.','work','discussion','','반대','찬성');
do $$ begin
 perform public.submit_topic_proposal('cccccccc-cccc-cccc-cccc-cccccccccccc','새로운 제안을 올려도 될까요?','하루에 세 번째 제안을 시도하고 있습니다.','work','discussion','','반대','찬성');
 raise exception 'FAIL rate limit';
exception when raise_exception then if SQLERRM='FAIL rate limit' then raise; end if; raise notice 'PASS daily rate limit'; end $$;
select public.withdraw_topic_proposal('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select public.topic_assert((select status='withdrawn' from public.topic_submissions where id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'withdraw pending');
reset role;
update public.topics set status='hidden' where origin='community';
set local role authenticated;
select public.topic_assert((select count(*)=0 from public.topics_feed where origin='community'),'hidden absent from feed');
select public.topic_assert((select count(*)=0 from public.world_scores),'hidden reactions inaccessible');
select public.topic_assert((select count(*)=0 from public.topic_stats),'hidden absent from aggregates');
do $$ begin
 insert into public.world_scores(user_id,topic_id,target_id,value) select auth.uid(),topic_id,'match',90 from public.topic_submissions where status='approved'
 on conflict(user_id,topic_id,target_id) do update set value=90;
 raise exception 'FAIL hidden scoring';
exception when insufficient_privilege then raise notice 'PASS hidden scoring denied'; end $$;
reset role;
update public.topics set status='live' where origin='community';
set local role authenticated;
set local request.jwt.claim.sub='66666666-6666-6666-6666-666666666666';
insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),'55555555-5555-5555-5555-555555555555');
select public.topic_assert((select count(*)=0 from public.topics_feed where origin='community'),'blocked proposer absent from feed');
select public.topic_assert((select count(*)=0 from public.topic_submission_notifications),'other user notifications private');
reset role;
-- Exercise rejection, duplicate linking, queue cap, and report resolution.
update public.topic_submissions set created_at=now()-interval '2 days';
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-5555-5555-555555555555';
do $$ begin
 perform public.submit_topic_proposal('dddddddd-dddd-dddd-dddd-dddddddddddd','뉴스 사실에 대해 이야기해요','사실에 기반한 사건을 함께 논의하려 합니다.','society','news','','반대','찬성');
 raise exception 'FAIL news missing source';
exception when check_violation then raise notice 'PASS news requires source'; end $$;
select public.submit_topic_proposal('dddddddd-dddd-dddd-dddd-dddddddddddd','중복 질문을 제안해 볼까요?','이미 있는 토픽으로 연결되는지 검증해요.','work','discussion','','반대','찬성');
reset role;
set local role service_role;
select public.review_topic_proposal('dddddddd-dddd-dddd-dddd-dddddddddddd',1,'duplicate','기존 토픽에서 참여해 주세요.','operator',(select topic_id from public.topic_submissions where status='approved'));
select public.topic_assert((select topic_id is not null and status='duplicate' from public.topic_submissions where id='dddddddd-dddd-dddd-dddd-dddddddddddd'),'duplicate links existing topic');
reset role;
set local role authenticated;
select public.submit_topic_proposal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','검토 후 반려할 제안입니다','운영 규칙에 따라 반려 사유를 전달해요.','work','discussion','','반대','찬성');
reset role;
set local role service_role;
select public.review_topic_proposal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',1,'rejected','광고성 제안은 게시할 수 없어요.','operator');
select public.topic_assert((select status='rejected' and topic_id is null from public.topic_submissions where id='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),'rejection creates no topic');
select public.resolve_topic_report((select id from public.reports where target_type='topic' limit 1),true);
select public.topic_assert((select status='actioned' from public.reports where target_type='topic' limit 1),'report action recorded');
select public.topic_assert((select status='hidden' from public.topics where origin='community'),'report hides topic');
reset role;
update public.topic_submissions set created_at=now()-interval '2 days';
set local role authenticated;
select public.submit_topic_proposal('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa','첫 번째 대기 중 제안입니다','검토 대기 개수 제한을 검증하는 제안입니다.','work','discussion','','반대','찬성');
select public.submit_topic_proposal('22222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa','두 번째 대기 중 제안입니다','검토 대기 개수 제한을 검증하는 제안입니다.','work','discussion','','반대','찬성');
reset role;
update public.topic_submissions set created_at=now()-interval '2 days';
set local role authenticated;
select public.submit_topic_proposal('33333333-aaaa-aaaa-aaaa-aaaaaaaaaaaa','세 번째 대기 중 제안입니다','검토 대기 개수 제한을 검증하는 제안입니다.','work','discussion','','반대','찬성');
do $$ begin
 perform public.submit_topic_proposal('44444444-aaaa-aaaa-aaaa-aaaaaaaaaaaa','네 번째 대기 중 제안입니다','검토 대기 개수 제한을 검증하는 제안입니다.','work','discussion','','반대','찬성');
 raise exception 'FAIL pending cap';
exception when raise_exception then if SQLERRM not like '%3건%' then raise; end if; raise notice 'PASS pending cap'; end $$;
reset role;
update public.profiles set is_banned=true where id='55555555-5555-5555-5555-555555555555';
set local role authenticated;
do $$ begin
 perform public.submit_topic_proposal('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa','제재된 계정의 수정 시도입니다','검토 대기 개수 제한을 검증하는 제안입니다.','work','discussion','','반대','찬성',1);
 raise exception 'FAIL banned edit';
exception when insufficient_privilege then raise notice 'PASS banned user cannot edit'; end $$;
reset role;
rollback;
