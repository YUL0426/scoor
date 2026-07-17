-- 0002_world.sql — Phase 1: World 토픽 스코어링
-- spec-13 §3.4, §12(Phase 1)
--
-- 토픽은 어드민이 큐레이션(생성/마감)하고 앱은 읽기 + 점수 제출만 한다.
-- 클라이언트가 쓰던 title 키는 여기서 topic_id(uuid) 키로 대체된다.

create table if not exists public.topics (
  id          uuid primary key default gen_random_uuid(),
  category    text not null check (category in (
                'sports','politics','society','entertainment',
                'stocks','crypto','tech','love','work','students','night')),
  title       text not null check (char_length(title) between 1 and 80),
  subtitle    text check (char_length(subtitle) <= 200),
  cover_emoji text,
  status      text not null default 'live' check (status in ('draft','live','closed')),
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_by  uuid references public.profiles on delete set null,
  created_at  timestamptz not null default now()
);

comment on column public.topics.category is
  'WorldCategory rawValue. check 제약은 iOS enum과 동기화되어야 한다.';
comment on column public.topics.status is
  'draft = 어드민 작성 중(비노출), live = 점수 제출 가능, closed = 읽기 전용.';

create index if not exists topics_live_idx
  on public.topics (status, created_at desc) where status = 'live';

-- 경기의 홈/어웨이/MVP처럼 한 토픽 안의 하위 채점 대상 (ScoorTarget.id).
create table if not exists public.topic_targets (
  topic_id uuid not null references public.topics on delete cascade,
  id       text not null,
  label    text not null,
  sort     smallint not null default 0,
  primary key (topic_id, id)
);

create table if not exists public.world_scores (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles on delete cascade,
  topic_id     uuid not null references public.topics on delete cascade,
  target_id    text not null,
  value        smallint not null check (value between 0 and 100),
  comment      text check (char_length(comment) <= 280),
  is_anonymous boolean not null default false,
  is_hidden    boolean not null default false,
  country_code text check (country_code ~ '^[A-Z]{2}$'),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- 재제출 = 수정. 한 사람이 같은 대상에 두 번 투표할 수 없다.
  unique (user_id, topic_id, target_id)
);

comment on column public.world_scores.is_anonymous is
  '게시 단위 익명 선택 (LightIdentity.isAnonymous). 기본은 닉네임 노출.';
comment on column public.world_scores.country_code is
  '제출 시점 프로필 스냅샷. 이후 프로필을 바꿔도 과거 지역 집계가 흔들리지 않는다.';

create index if not exists world_scores_topic_idx
  on public.world_scores (topic_id, created_at desc) where not is_hidden;

drop trigger if exists world_scores_touch_updated_at on public.world_scores;
create trigger world_scores_touch_updated_at
  before update on public.world_scores
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 집계
-- ---------------------------------------------------------------------------

-- 토픽별 평균/참여수/등락. WorldTopic(globalScore, scoreDelta, postsCount,
-- lastActivityAt)에 그대로 매핑된다. heat 분류는 클라이언트가 이 값으로 파생.
--
-- 뷰(materialized 아님)인 이유: Phase 1 규모에서는 실시간성이 더 중요하고,
-- world_scores_topic_idx로 충분히 빠르다. 부하가 문제가 되면 materialized +
-- pg_cron으로 바꾼다 (spec-13 §3.7의 pulse_stats와 같은 방식).
create or replace view public.topic_stats as
select
  t.id                                             as topic_id,
  count(ws.*)                                      as posts_count,
  round(avg(ws.value))::smallint                   as global_score,
  coalesce(round(
    avg(ws.value) filter (where ws.created_at > now() - interval '1 hour')
    - avg(ws.value) filter (where ws.created_at <= now() - interval '1 hour')
  ), 0)::smallint                                  as score_delta,
  max(ws.created_at)                               as last_activity_at
from public.topics t
left join public.world_scores ws
  on ws.topic_id = t.id and not ws.is_hidden
group by t.id;

-- 지역별 반응(RegionalReaction). k-익명성: 표본 5 미만 지역은 노출하지 않는다
-- (spec-13 §8.3). 콜드 스타트 구간에 한두 명의 점수가 "한국 평균"으로
-- 둔갑하는 것을 막는다.
create or replace view public.topic_region_stats as
select
  ws.topic_id,
  ws.country_code,
  round(avg(ws.value))::smallint as avg_score,
  count(*)                       as participants
from public.world_scores ws
where not ws.is_hidden and ws.country_code is not null
group by ws.topic_id, ws.country_code
having count(*) >= 5;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.topics        enable row level security;
alter table public.topic_targets enable row level security;
alter table public.world_scores  enable row level security;

-- 토픽은 읽기 전용 공개. 생성/수정은 service-role(어드민)만 — service_role은
-- RLS를 우회하므로 별도 정책이 필요 없다.
drop policy if exists topics_read_live on public.topics;
create policy topics_read_live on public.topics
  for select using (status in ('live', 'closed'));

drop policy if exists topic_targets_read on public.topic_targets;
create policy topic_targets_read on public.topic_targets
  for select using (
    exists (select 1 from public.topics t
            where t.id = topic_id and t.status in ('live', 'closed'))
  );

-- 월드 점수 읽기: 숨김 처리된 것과 내가 차단한 사용자의 것은 제외.
drop policy if exists world_scores_read on public.world_scores;
create policy world_scores_read on public.world_scores
  for select using (
    not is_hidden
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = world_scores.user_id
    )
  );

-- 쓰기: 본인 + live 토픽에만. 마감된 토픽에 점수를 넣을 수 없다.
drop policy if exists world_scores_insert_own on public.world_scores;
create policy world_scores_insert_own on public.world_scores
  for insert with check (
    user_id = auth.uid()
    and exists (select 1 from public.topics t
                where t.id = topic_id and t.status = 'live')
    and not exists (select 1 from public.profiles p
                    where p.id = auth.uid() and p.is_banned)
  );

drop policy if exists world_scores_update_own on public.world_scores;
create policy world_scores_update_own on public.world_scores
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.topics t
                where t.id = topic_id and t.status = 'live')
  );

drop policy if exists world_scores_delete_own on public.world_scores;
create policy world_scores_delete_own on public.world_scores
  for delete using (user_id = auth.uid());
