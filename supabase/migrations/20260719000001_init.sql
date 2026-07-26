-- 0001_init.sql — Phase 0 기반: 프로필 + 개인 점수
-- spec-13 §3.1, §3.2, §3.8
--
-- auth.users가 인증 원장이고 public.profiles가 앱이 읽는 미러다.
-- 개인 점수(scores)는 local-first — SwiftData가 UI 진실의 원천이고 이 테이블은
-- 백업/멀티디바이스 계층이다. 충돌은 (user_id, day) 단위 last-write-wins.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  username     text unique not null check (char_length(username) between 2 and 20),
  avatar_emoji text,
  avatar_url   text,
  bio          text check (char_length(bio) <= 160),
  country_code text check (country_code ~ '^[A-Z]{2}$'),
  city         text,
  is_banned    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is
  '앱이 읽는 공개 프로필. auth.users가 인증 원장이고 이 테이블은 미러다.';
comment on column public.profiles.country_code is
  'ISO 3166-1 alpha-2. GPS 미사용 — 사용자가 설정에서 수동 선택한다 (spec-13 §9).';

-- 신규 가입 시 프로필 자동 생성. username은 충돌을 피하려 임시값으로 두고
-- 클라이언트가 온보딩/마이그레이션(§7)에서 실제 닉네임으로 갱신한다.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    -- uuid 앞 8자 → 충돌 확률이 실질적으로 0이면서 2~20자 제약을 만족.
    'scoor_' || substr(replace(new.id::text, '-', ''), 1, 8)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at 자동 갱신.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- scores (개인 점수 — 동기화 대상)
-- ---------------------------------------------------------------------------

create table if not exists public.scores (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles on delete cascade,
  day               date not null,
  value             smallint not null check (value between 0 and 100),
  reason            text check (char_length(reason) <= 200),
  mood              text,
  -- 충돌 해결 키. 클라이언트가 로컬 기록 시각을 보내고 서버는 더 최신인 쓰기만 반영한다.
  client_updated_at timestamptz not null,
  deleted_at        timestamptz,
  created_at        timestamptz not null default now(),
  -- "하루 1점수" 규칙을 서버에서도 강제 — 클라이언트 버그가 있어도 중복이 안 생긴다.
  unique (user_id, day)
);

comment on column public.scores.day is
  '캘린더 일자. 클라이언트 로컬 타임존 기준 startOfDay에서 파생된다.';
comment on column public.scores.deleted_at is
  'tombstone. 삭제를 다른 기기로 전파하려면 행이 남아 있어야 한다 (spec-13 §5).';

-- 풀 동기화(GET /scores?since=)의 주 경로.
create index if not exists scores_user_updated_idx
  on public.scores (user_id, client_updated_at desc);

-- Last-write-wins를 서버가 강제한다. PostgREST의 upsert(merge-duplicates)는
-- 무조건 덮어쓰므로, 이 트리거 없이는 기기 A의 지연 업로드(옛 쓰기)가 기기 B의
-- 최신 쓰기를 덮어쓸 수 있다. 더 오래된 쓰기는 조용히 무시된다 — 클라이언트는
-- 재시도할 필요가 없고(멱등), 최신 상태가 항상 승리한다.
create or replace function public.scores_last_write_wins()
returns trigger
language plpgsql
as $$
begin
  if new.client_updated_at < old.client_updated_at then
    return null; -- BEFORE UPDATE에서 null 반환 = 이 행 갱신 건너뜀
  end if;
  return new;
end;
$$;

drop trigger if exists scores_lww on public.scores;
create trigger scores_lww
  before update on public.scores
  for each row execute function public.scores_last_write_wins();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.scores   enable row level security;

-- profiles: 공개 읽기(차단된 계정 제외), 본인만 수정.
-- 삽입은 트리거(security definer)가 하므로 insert 정책을 열지 않는다.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select using (not is_banned or id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- scores: 본인만 전부. 개인 저널은 절대 공개되지 않는다 — 피드 공유는
-- posts 테이블로의 명시적 복사이지 이 테이블 노출이 아니다 (share is opt-in).
drop policy if exists scores_own on public.scores;
create policy scores_own on public.scores
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
