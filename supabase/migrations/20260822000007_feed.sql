-- 0007_feed.sql — 피드 실데이터 (spec-13 §3.3, Phase 2 읽기 경로)
--
-- 지금까지 Feed 탭은 `SocialSeed`가 만든 가짜 글을 보여줬다. 배너로 "예시
-- 콘텐츠"라고 라벨링해 두긴 했지만, 출시 앱의 탭 하나가 통째로 견본인 상태다.
-- 이 마이그레이션이 그 탭에 실제 저장소를 준다.
--
-- ---------------------------------------------------------------------------
-- 공식 글(is_official)이 왜 있는가
-- ---------------------------------------------------------------------------
-- 앱에는 아직 글 작성 UI가 없다 (SocialServiceProtocol에 생성 메서드 자체가
-- 없다 — Phase 2 항목). 그래서 출시 시점의 피드는 어드민이 등록한 글로 시작한다.
--
-- 그 글은 **반드시 공식 글로 표시된다** — author_id가 null이고 is_official이
-- true이며, 앱은 "Scoor" 이름과 배지로 렌더링한다. 운영자가 쓴 글에 사람 이름을
-- 붙여 일반 사용자 글처럼 내보내는 것은 P0-1이 지적한 바로 그 문제(가짜 소셜
-- 데이터)로 되돌아가는 길이고, 심사에서도 조작된 UGC로 읽힌다.
--
-- 사용자 글 경로(author_id not null)는 스키마·RLS 모두 지금 열어 둔다. Phase 2에서
-- 작성 UI만 붙이면 되고, 그때 이 테이블을 다시 설계할 필요가 없다.

-- ---------------------------------------------------------------------------
-- posts
-- ---------------------------------------------------------------------------

create table if not exists public.posts (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid references public.profiles on delete cascade,
  is_official  boolean not null default false,
  score        smallint not null check (score between 0 and 100),
  message      text not null check (char_length(message) between 1 and 280),
  primary_mood text not null,                  -- Mood rawValue
  extra_moods  text[] not null default '{}',
  weather      text,                           -- Weather rawValue, nullable
  is_anonymous boolean not null default false,
  country_code text check (country_code ~ '^[A-Z]{2}$'),
  city         text,
  source_day   date,
  is_hidden    boolean not null default false, -- 모더레이션 숨김
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  -- 공식 글에는 작성자가 없고, 사용자 글에는 반드시 있다. 이 제약이 없으면
  -- "작성자 있는 공식 글"이라는, 렌더링할 방법이 없는 상태가 만들어진다.
  constraint posts_author_matches_official
    check ((is_official and author_id is null) or (not is_official and author_id is not null))
);

comment on table public.posts is
  '감정 커뮤니티 피드. is_official = 어드민이 등록한 공식 글(작성자 없음, 앱에서 배지 표시).';

create index if not exists posts_visible_idx
  on public.posts (created_at desc)
  where deleted_at is null and not is_hidden;
create index if not exists posts_author_idx on public.posts (author_id);

-- ---------------------------------------------------------------------------
-- post_likes / comments
-- ---------------------------------------------------------------------------

create table if not exists public.post_likes (
  post_id    uuid not null references public.posts on delete cascade,
  user_id    uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts on delete cascade,
  author_id    uuid not null references public.profiles on delete cascade,
  text         text not null check (char_length(text) between 1 and 280),
  is_anonymous boolean not null default false,
  edited_at    timestamptz,
  is_hidden    boolean not null default false,
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create index if not exists comments_post_idx
  on public.comments (post_id, created_at)
  where deleted_at is null and not is_hidden;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.posts      enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments   enable row level security;

-- 읽기는 게스트에게도 열린다 (spec-13 §15-1: 비로그인 둘러보기 허용).
-- 차단은 차단자 본인에게만 적용되며, auth.uid()가 null인 anon에게는
-- 하위 질의가 0행이라 자연히 무해하다.
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts
  for select to anon, authenticated
  using (
    deleted_at is null
    and not is_hidden
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = posts.author_id
    )
  );

-- 사용자 글 쓰기. 공식 글은 여기에 해당하지 않는다 — is_official을 막아
-- 일반 사용자가 공식 배지를 달 수 없게 한다 (service_role은 RLS를 우회한다).
drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own on public.posts
  for insert to authenticated
  with check (author_id = auth.uid() and not is_official);

drop policy if exists posts_update_own on public.posts;
create policy posts_update_own on public.posts
  for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid() and not is_official);

drop policy if exists posts_delete_own on public.posts;
create policy posts_delete_own on public.posts
  for delete to authenticated
  using (author_id = auth.uid());

-- 좋아요 수는 공개 정보다. 누가 눌렀는지도 마찬가지 — 프로필과 달리 숨길 것이 없다.
drop policy if exists post_likes_read on public.post_likes;
create policy post_likes_read on public.post_likes
  for select to anon, authenticated using (true);

drop policy if exists post_likes_write_own on public.post_likes;
create policy post_likes_write_own on public.post_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists post_likes_delete_own on public.post_likes;
create policy post_likes_delete_own on public.post_likes
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists comments_read on public.comments;
create policy comments_read on public.comments
  for select to anon, authenticated
  using (
    deleted_at is null
    and not is_hidden
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = comments.author_id
    )
  );

drop policy if exists comments_insert_own on public.comments;
create policy comments_insert_own on public.comments
  for insert to authenticated with check (author_id = auth.uid());

drop policy if exists comments_update_own on public.comments;
create policy comments_update_own on public.comments
  for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists comments_delete_own on public.comments;
create policy comments_delete_own on public.comments
  for delete to authenticated using (author_id = auth.uid());

-- ---------------------------------------------------------------------------
-- feed_posts — 앱이 실제로 읽는 평탄한 뷰
-- ---------------------------------------------------------------------------
--
-- topics_feed와 같은 이유로 뷰를 둔다: PostgREST는 테이블↔뷰 임베딩을 못 하고,
-- 앱은 글 + 작성자 + 집계를 한 왕복에 받아야 한다.
--
-- security_invoker = true가 핵심이다. 기본값(정의자 권한)이면 뷰가 기저 테이블의
-- RLS를 우회해 숨김 글과 차단한 사람의 글이 그대로 새어 나온다 — 0005 검증 때
-- draft 토픽이 뷰로 새던 것과 똑같은 실수다.

drop view if exists public.feed_posts;
create view public.feed_posts
with (security_invoker = true) as
select
  p.id,
  p.is_official,
  p.score,
  p.message,
  p.primary_mood,
  p.extra_moods,
  p.weather,
  p.is_anonymous,
  p.country_code,
  p.city,
  p.created_at,
  -- 앱에는 어차피 보이지 않는 행의 플래그다 (RLS가 먼저 거른다). 어드민은
  -- service_role로 붙어 RLS를 우회하므로, 이 두 칼럼 덕분에 같은 뷰 하나로
  -- 숨김·삭제된 글까지 집계와 함께 볼 수 있다 — 모더레이션 화면이 posts를
  -- 따로 조인할 필요가 없어진다.
  p.is_hidden,
  p.deleted_at,
  case
    when p.is_official   then 'Scoor'
    when p.is_anonymous  then null
    else pr.username
  end                                    as author_name,
  pr.avatar_emoji                        as author_emoji,
  -- 신고 화면이 "이 사람 차단"까지 제안하려면 작성자 id가 필요하다. 익명 글과
  -- 공식 글에서는 null이다 — 익명 글의 작성자를 돌려주면 익명이 아니게 된다.
  case when p.is_anonymous or p.is_official then null else p.author_id end as author_id,
  coalesce(l.likes_count, 0)             as likes_count,
  coalesce(c.comments_count, 0)          as comments_count,
  exists (
    select 1 from public.post_likes pl
    where pl.post_id = p.id and pl.user_id = auth.uid()
  )                                      as liked_by_me
from public.posts p
left join public.profiles pr on pr.id = p.author_id
left join (
  select post_id, count(*) as likes_count
  from public.post_likes group by post_id
) l on l.post_id = p.id
left join (
  select post_id, count(*) as comments_count
  from public.comments
  where deleted_at is null and not is_hidden
  group by post_id
) c on c.post_id = p.id;

comment on view public.feed_posts is
  'Feed 탭 목록용. posts + profiles + 좋아요/댓글 집계를 미리 조인한 평탄한 형태. security_invoker라 posts의 RLS(숨김·차단)가 그대로 적용된다.';

-- ---------------------------------------------------------------------------
-- GRANT (0004의 교훈: RLS만으로는 열리지 않는다)
-- ---------------------------------------------------------------------------

grant select on public.posts      to anon, authenticated;
grant select on public.post_likes to anon, authenticated;
grant select on public.comments   to anon, authenticated;
grant select on public.feed_posts to anon, authenticated;

grant insert, update, delete on public.posts      to authenticated;
grant insert, delete         on public.post_likes to authenticated;
grant insert, update, delete on public.comments   to authenticated;

-- 어드민(공식 글 등록·모더레이션)은 service_role로 붙는다. 0006이 default
-- privileges를 걸어 두었지만, 그 시점 이후 생성된 테이블에만 적용되므로
-- 여기서 명시적으로도 준다 — 0004가 service_role을 빠뜨려 터진 적이 있다.
grant all privileges on public.posts      to service_role;
grant all privileges on public.post_likes to service_role;
grant all privileges on public.comments   to service_role;
grant select         on public.feed_posts to service_role;
