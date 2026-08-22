-- feed_rls.sql — 0007_feed.sql 동작 검증 (로컬 Postgres)
--
-- 문법이 아니라 "정책이 의도대로 동작하는가"를 본다. 0005 검증 때 draft 토픽이
-- 뷰로 새던 것처럼, 이 층의 결함은 SQL을 실제로 돌려보지 않으면 코드 리뷰로
-- 드러나지 않는다.
--
-- 사용법 (Postgres 17 기준):
--   initdb -D /tmp/scoor-pg --locale=C -U postgres --auth=trust
--   pg_ctl -D /tmp/scoor-pg -o "-p 55432 -k /tmp" -l /tmp/scoor-pg.log start
--   createdb -h 127.0.0.1 -p 55432 -U postgres scoor_test
--   psql ... -f supabase/tests/auth_shim.sql
--   for f in supabase/migrations/*.sql; do psql ... -f "$f"; done
--   psql ... -f supabase/tests/feed_rls.sql
--
-- 17건 전부 PASS여야 한다. 하나라도 FAIL이면 exception으로 즉시 멈춘다.

\set ON_ERROR_STOP on
\pset pager off


create or replace function public.assert(cond boolean, label text) returns void
language plpgsql as $$
begin
  if cond then raise notice 'PASS  %', label;
  else raise exception 'FAIL  %', label;
  end if;
end $$;

-- 사용자 두 명
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.com');

update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob'   where id = '22222222-2222-2222-2222-222222222222';

-- 어드민(service_role)이 공식 글 등록
set role service_role;
insert into public.posts (id, is_official, score, message, primary_mood)
values ('aaaaaaaa-0000-0000-0000-000000000001', true, 72, '오늘 하루는 몇 점인가요?', 'calm');
reset role;
select public.assert((select count(*) = 1 from public.posts where is_official), '1. service_role이 공식 글을 등록한다');

-- 제약: 공식 글에 작성자를 붙일 수 없다
do $$
begin
  insert into public.posts (author_id, is_official, score, message, primary_mood)
  values ('11111111-1111-1111-1111-111111111111', true, 50, 'x', 'calm');
  raise exception 'FAIL  2. 공식+작성자 조합이 통과해 버렸다';
exception when check_violation then
  raise notice 'PASS  2. 공식 글에 작성자를 붙이면 제약이 막는다';
end $$;

-- 게스트(anon)가 공식 글을 읽는다
set role anon;
select public.assert((select count(*) = 1 from public.feed_posts), '3. 비로그인 게스트가 피드를 읽는다');
select public.assert((select author_name = 'Scoor' from public.feed_posts limit 1), '4. 공식 글 작성자명이 Scoor로 나온다');
reset role;

-- 사용자 글 쓰기
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.posts (id, author_id, score, message, primary_mood)
values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 88, '좋은 하루였다', 'happy');
select public.assert((select count(*) = 2 from public.feed_posts), '5. 사용자가 자기 글을 쓰고 피드에 나타난다');

-- 사용자는 공식 배지를 달 수 없다
do $$
begin
  insert into public.posts (author_id, is_official, score, message, primary_mood)
  values ('11111111-1111-1111-1111-111111111111', true, 50, 'x', 'calm');
  raise exception 'FAIL  6. 일반 사용자가 공식 글을 만들 수 있다';
exception when insufficient_privilege or check_violation then
  raise notice 'PASS  6. 일반 사용자는 공식 배지를 달 수 없다';
end $$;

-- 남의 글로 위장 불가
do $$
begin
  insert into public.posts (author_id, score, message, primary_mood)
  values ('22222222-2222-2222-2222-222222222222', 50, 'bob인 척', 'calm');
  raise exception 'FAIL  7. 남의 이름으로 글을 쓸 수 있다';
exception when insufficient_privilege then
  raise notice 'PASS  7. 남의 이름으로는 글을 쓸 수 없다';
end $$;

-- 좋아요
insert into public.post_likes (post_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
select public.assert(
  (select liked_by_me and likes_count = 1 from public.feed_posts where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '8. 좋아요가 집계되고 liked_by_me가 켜진다');

-- 댓글
insert into public.comments (post_id, author_id, text)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '75점이요');
select public.assert(
  (select comments_count = 1 from public.feed_posts where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '9. 댓글 수가 집계된다');
reset role;
reset request.jwt.claim.sub;

-- B가 A를 차단하면 A의 글이 B에게만 사라진다
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into public.blocks (blocker_id, blocked_id)
values ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');
select public.assert((select count(*) = 1 from public.feed_posts), '10. 차단하면 그 사람 글이 내 피드에서 사라진다');
select public.assert(
  (select count(*) = 0 from public.comments where post_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '11. 차단한 사람의 댓글도 사라진다');
reset role;
reset request.jwt.claim.sub;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.assert((select count(*) = 2 from public.feed_posts), '12. 차단은 단방향 — A에게는 그대로 보인다');
reset role;
reset request.jwt.claim.sub;

-- 모더레이션 숨김
set role service_role;
update public.posts set is_hidden = true where id = 'aaaaaaaa-0000-0000-0000-000000000002';
reset role;
set role anon;
select public.assert((select count(*) = 1 from public.feed_posts), '13. 숨김 처리한 글은 뷰에서 사라진다 (security_invoker)');
reset role;

-- soft delete
set role service_role;
update public.posts set is_hidden = false, deleted_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000002';
reset role;
set role anon;
select public.assert((select count(*) = 1 from public.feed_posts), '14. 삭제한 글도 뷰에서 사라진다');
reset role;

-- 계정 삭제 CASCADE
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
select public.assert((select count(*) = 0 from public.posts where author_id = '11111111-1111-1111-1111-111111111111'), '15. 계정 삭제 시 글이 CASCADE로 사라진다');
select public.assert((select count(*) = 0 from public.comments), '16. 계정 삭제 시 댓글도 사라진다');
select public.assert((select count(*) = 0 from public.post_likes), '17. 계정 삭제 시 좋아요도 사라진다');
