-- 어드민 큐레이션 시작 토픽 (spec-13 §8 콜드 스타트, §15-4 일 3~5개)
--
-- 마이그레이션이 아니라 시드다. 토픽은 운영 데이터이지 스키마가 아니며,
-- 매일 새로 큐레이션되므로 마이그레이션 이력에 박제하면 안 된다.
-- 실행: supabase db query --linked -f supabase/seed/topics.sql
--
-- 콜드 스타트 원칙 (§8-1): 운영팀이 **토픽만** 제공한다. 일반 유저인 척하는
-- 가짜 계정으로 반응을 채우지 않는다 — 그것이 정확히 P0-1(가짜 소셜 데이터)의
-- 재발이다. 반응 수가 0이면 0으로 보이는 것이 맞다.
--
-- 재실행 안전: 같은 제목의 live 토픽이 이미 있으면 건너뛴다.

insert into public.topics (category, title, subtitle, cover_emoji, status)
select * from (values
  ('night',    '오늘 밤, 잠이 안 오는 이유',
               '새벽에 깨어 있는 사람들의 점수', '🌙', 'live'),
  ('work',     '이번 주 직장 컨디션',
               '월요일부터 지금까지, 몇 점인가요', '💼', 'live'),
  ('society',  '요즘 뉴스 보면 드는 기분',
               '세상 돌아가는 걸 점수로', '🌧', 'live'),
  ('students', '시험 기간 멘탈',
               '공부하는 사람들의 실시간 감정', '📚', 'live'),
  ('love',     '지금 내 연애 온도',
               '설렘부터 권태까지', '❤️', 'live')
) as t(category, title, subtitle, cover_emoji, status)
where not exists (
  select 1 from public.topics existing
  where existing.title = t.title and existing.status = 'live'
);

-- 하위 채점 대상이 없는 토픽은 단일 타겟 'main'을 쓴다.
-- (스포츠 토픽만 match/team/mvp로 쪼갠다 — ScoorTarget.id와 같은 규칙)
insert into public.topic_targets (topic_id, id, label, sort)
select t.id, 'main', '전체', 0
from public.topics t
where t.status = 'live'
  and not exists (
    select 1 from public.topic_targets tt where tt.topic_id = t.id and tt.id = 'main'
  );

select title, category, status from public.topics order by created_at desc;
