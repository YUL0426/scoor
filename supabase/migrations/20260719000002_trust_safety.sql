-- 0002_trust_safety.sql — 신고 / 차단
-- spec-13 §3.6, §9
--
-- App Store Guideline 1.2는 UGC 앱에 신고·차단·모더레이션을 요구한다.
-- Phase 1에서 World 코멘트에 먼저 적용하고 Phase 2에서 피드로 확장한다.
-- world_scores/posts의 읽기 정책이 blocks를 참조하므로 이 마이그레이션이
-- 그보다 먼저 실행되어야 한다.

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles on delete cascade,
  blocked_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

comment on table public.blocks is
  '단방향 차단. 차단자의 피드/댓글/게스트북에서 대상 콘텐츠가 즉시 사라진다.';

-- 읽기 정책이 매 행마다 "내가 이 작성자를 차단했나"를 조회하므로
-- blocker_id 선두 인덱스(= PK)가 핵심 경로다. 역방향 조회용 인덱스도 둔다.
create index if not exists blocks_blocked_idx on public.blocks (blocked_id);

create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles on delete cascade,
  target_type text not null check (target_type in
                ('post','comment','guestbook','user','world_score')),
  target_id   uuid not null,
  reason      text not null check (reason in ('spam','abuse','self_harm','other')),
  detail      text check (char_length(detail) <= 500),
  status      text not null default 'open'
                check (status in ('open','reviewed','actioned','dismissed')),
  created_at  timestamptz not null default now(),
  -- 같은 대상을 반복 신고해 큐를 오염시키는 것을 막는다.
  unique (reporter_id, target_type, target_id)
);

comment on table public.reports is
  '모더레이션 큐의 입력. 어드민이 service-role로 읽고 처리한다 (24h SLA 목표).';

create index if not exists reports_open_idx
  on public.reports (created_at) where status = 'open';

-- 커뮤니티 가이드라인 동의 이력 (최초 게시 전 1회, spec-13 §9).
create table if not exists public.guideline_acceptances (
  user_id     uuid primary key references public.profiles on delete cascade,
  version     text not null,
  accepted_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.blocks               enable row level security;
alter table public.reports              enable row level security;
alter table public.guideline_acceptances enable row level security;

-- 차단은 당사자(차단한 쪽)만 보고 관리한다. 차단당한 쪽에는 노출되지 않는다 —
-- 차단 사실 자체가 보이면 보복 유인이 생긴다.
drop policy if exists blocks_own on public.blocks;
create policy blocks_own on public.blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- 신고는 넣을 수만 있고 읽지 못한다. 처리 현황 조회는 어드민(service-role) 전용.
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert with check (reporter_id = auth.uid());

drop policy if exists guideline_own on public.guideline_acceptances;
create policy guideline_own on public.guideline_acceptances
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
