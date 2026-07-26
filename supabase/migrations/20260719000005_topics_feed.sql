-- 0005_topics_feed.sql — 앱이 실제로 읽는 토픽 목록 뷰
--
-- 앱은 topics + 집계를 한 번에 필요로 하는데, PostgREST는 테이블↔뷰 임베딩을
-- 지원하지 않는다(FK 관계를 찾지 못해 PGRST200으로 쿼리 전체가 실패한다).
-- 그래서 조인을 DB 쪽에서 끝낸 평탄한 뷰를 하나 노출한다 — 클라이언트는
-- 단일 select만 하면 되고, 왕복도 한 번이다.
--
-- 집계가 없는(아직 아무도 점수를 안 매긴) 토픽도 반드시 나와야 한다.
-- 콜드 스타트 구간에는 그런 토픽이 대부분이며, 안 보이면 World가 빈 화면이 된다.
-- → left join + coalesce.

create or replace view public.topics_feed as
select
  t.id,
  t.category,
  t.title,
  t.subtitle,
  t.cover_emoji,
  t.status,
  t.created_at,
  coalesce(s.posts_count, 0)                as posts_count,
  coalesce(s.global_score, 0)               as global_score,
  coalesce(s.score_delta, 0)                as score_delta,
  coalesce(s.last_activity_at, t.created_at) as last_activity_at
from public.topics t
left join public.topic_stats s on s.topic_id = t.id
where t.status in ('live', 'closed');

comment on view public.topics_feed is
  'World 탭 목록용. topics + topic_stats를 미리 조인한 평탄한 형태 — PostgREST가 뷰를 임베딩하지 못하기 때문이다.';

grant select on public.topics_feed to anon, authenticated;
