-- Reposts keep a reference to the original post. RLS on posts remains authoritative.
create table public.post_reposts (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index post_reposts_user_created_idx on public.post_reposts (user_id, created_at desc);
alter table public.post_reposts enable row level security;
create policy post_reposts_read on public.post_reposts
  for select to anon, authenticated using (
    user_id = auth.uid() or exists (select 1 from public.posts p where p.id = post_id)
  );
create policy post_reposts_insert on public.post_reposts
  for insert to authenticated with check (
    user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_id and p.deleted_at is null and not p.is_hidden)
  );
create policy post_reposts_update on public.post_reposts
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_id and p.deleted_at is null and not p.is_hidden));
create policy post_reposts_delete on public.post_reposts
  for delete to authenticated using (user_id = auth.uid());
grant select on public.post_reposts to anon, authenticated;
grant insert, update, delete on public.post_reposts to authenticated;
grant all on public.post_reposts to service_role;

create or replace view public.feed_posts
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
  )                                      as liked_by_me,
  (select count(*) from public.post_reposts r where r.post_id = p.id) as reposts_count,
  exists (select 1 from public.post_reposts r where r.post_id = p.id and r.user_id = auth.uid()) as reposted_by_me,
  (select r.created_at from public.post_reposts r where r.post_id = p.id and r.user_id = auth.uid()) as reposted_at
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
