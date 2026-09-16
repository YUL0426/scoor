-- Community proposals are private until an authenticated operator approves them.
begin;
alter table public.topics drop constraint topics_status_check;
alter table public.topics add constraint topics_status_check check (status in ('draft','live','closed','hidden'));
alter table public.topics add column origin text not null default 'admin' check (origin in ('admin','community')),
 add column proposed_by uuid references public.profiles on delete set null,
 add column source_url text,
 add column score_low_label text not null default '부정적',
 add column score_high_label text not null default '긍정적';

create table public.topic_submissions (
 id uuid primary key,
 user_id uuid not null references public.profiles on delete cascade,
 title text not null check (char_length(btrim(title)) between 5 and 80),
 subtitle text not null check (char_length(btrim(subtitle)) between 10 and 200),
 category text not null check (category in ('sports','politics','society','entertainment','stocks','crypto','tech','love','work','students','night')),
 kind text not null check (kind in ('discussion','news')),
 source_url text check (source_url is null or (char_length(source_url)<=2000 and source_url ~ '^https://[^[:space:]]+')),
 score_low_label text not null check (char_length(btrim(score_low_label)) between 1 and 20),
 score_high_label text not null check (char_length(btrim(score_high_label)) between 1 and 20),
 status text not null default 'pending' check (status in ('pending','changes_requested','approved','rejected','duplicate','withdrawn')),
 revision integer not null default 1,
 review_reason text check (char_length(review_reason)<=500),
 reviewed_by text,
 reviewed_at timestamptz,
 topic_id uuid references public.topics on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (kind <> 'news' or source_url is not null),
 check (score_low_label <> score_high_label)
);
create index topic_submissions_owner on public.topic_submissions(user_id,created_at desc);
create index topic_submissions_queue on public.topic_submissions(status,updated_at);
alter table public.topic_submissions enable row level security;
create policy submissions_read_own on public.topic_submissions for select to authenticated using (user_id=auth.uid());
revoke all on public.topic_submissions from anon, authenticated;
grant select on public.topic_submissions to authenticated;
grant all on public.topic_submissions to service_role;

-- Durable in-app review notifications; no device permission or push token required.
create table public.topic_submission_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles on delete cascade,
 submission_id uuid not null references public.topic_submissions on delete cascade,
 revision integer not null,
 status text not null,
 title text not null,
 reason text,
 topic_id uuid references public.topics on delete set null,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(submission_id,revision)
);
alter table public.topic_submission_notifications enable row level security;
create policy topic_notifications_read on public.topic_submission_notifications for select to authenticated using(user_id=auth.uid());
create policy topic_notifications_update on public.topic_submission_notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
revoke all on public.topic_submission_notifications from anon, authenticated;
grant select, update(read_at) on public.topic_submission_notifications to authenticated;
grant all on public.topic_submission_notifications to service_role;

create function public.submit_topic_proposal(p_id uuid, p_title text, p_subtitle text, p_category text,
 p_kind text, p_source_url text, p_low text, p_high text, p_revision integer default null)
returns public.topic_submissions language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.topic_submissions; uid uuid:=auth.uid();
begin
 if uid is null then raise exception '로그인이 필요합니다.' using errcode='42501'; end if;
 -- One lock per account makes limits safe against concurrent requests.
 perform 1 from public.profiles where id=uid and not is_banned for update;
 if not found then raise exception '제안할 수 없는 계정입니다.' using errcode='42501'; end if;
 if not exists(select 1 from public.guideline_acceptances where user_id=uid and version='1.0') then
  raise exception '커뮤니티 가이드에 먼저 동의해 주세요.' using errcode='42501'; end if;
 select * into s from public.topic_submissions where id=p_id for update;
 if found then
  if s.user_id<>uid then raise exception '다른 사용자의 제안입니다.' using errcode='42501'; end if;
  -- Exact replays after an uncertain response are idempotent, even after review.
  if (s.title,s.subtitle,s.category,s.kind,s.source_url,s.score_low_label,s.score_high_label)
     is not distinct from (btrim(p_title),btrim(p_subtitle),p_category,p_kind,nullif(btrim(p_source_url),''),btrim(p_low),btrim(p_high)) then return s; end if;
  if s.status not in ('pending','changes_requested') or s.revision is distinct from p_revision then
   raise exception '제안 상태가 변경되었습니다. 새로고침해 주세요.' using errcode='40001'; end if;
  update public.topic_submissions set title=btrim(p_title),subtitle=btrim(p_subtitle),category=p_category,
   kind=p_kind,source_url=nullif(btrim(p_source_url),''),score_low_label=btrim(p_low),score_high_label=btrim(p_high),
   status='pending',revision=revision+1,review_reason=null,reviewed_by=null,reviewed_at=null,updated_at=now()
  where id=p_id returning * into s;
 else
  if (select count(*) from public.topic_submissions where user_id=uid and created_at>now()-interval '24 hours')>=2 then
   raise exception '최근 24시간 동안 2건까지 제안할 수 있어요.'; end if;
  if (select count(*) from public.topic_submissions where user_id=uid and status in ('pending','changes_requested'))>=3 then
   raise exception '검토 대기 중인 제안은 3건까지 가능해요.'; end if;
  insert into public.topic_submissions(id,user_id,title,subtitle,category,kind,source_url,score_low_label,score_high_label)
  values(p_id,uid,btrim(p_title),btrim(p_subtitle),p_category,p_kind,nullif(btrim(p_source_url),''),btrim(p_low),btrim(p_high)) returning * into s;
 end if;
 return s;
end $$;
revoke all on function public.submit_topic_proposal(uuid,text,text,text,text,text,text,text,integer) from public;
grant execute on function public.submit_topic_proposal(uuid,text,text,text,text,text,text,text,integer) to authenticated;

create function public.withdraw_topic_proposal(p_id uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.topic_submissions set status='withdrawn',revision=revision+1,updated_at=now()
 where id=p_id and user_id=auth.uid() and status in ('pending','changes_requested');
 if not found then raise exception '철회할 수 없는 제안입니다.'; end if;
end $$;
revoke all on function public.withdraw_topic_proposal(uuid) from public;
grant execute on function public.withdraw_topic_proposal(uuid) to authenticated;

create function public.review_topic_proposal(p_id uuid,p_revision integer,p_action text,p_reason text,p_reviewer text,p_topic_id uuid default null)
returns public.topic_submissions language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.topic_submissions; published uuid;
begin
 select * into s from public.topic_submissions where id=p_id for update;
 if not found then raise exception '제안을 찾을 수 없습니다.'; end if;
 if s.status='approved' and p_action='approved' then return s; end if;
 if s.status<>'pending' or s.revision<>p_revision then raise exception '제안이 변경되었습니다. 새로고침 후 검토해 주세요.' using errcode='40001'; end if;
 if p_action not in ('approved','changes_requested','rejected','duplicate') then raise exception '올바르지 않은 심사 결과입니다.'; end if;
 if nullif(btrim(p_reviewer),'') is null then raise exception '검토자 정보가 필요합니다.'; end if;
 if p_action<>'approved' and nullif(btrim(p_reason),'') is null then raise exception '처리 사유가 필요합니다.'; end if;
 if p_action='approved' then
  if exists(select 1 from public.profiles where id=s.user_id and is_banned) then raise exception '제재된 계정의 제안입니다.'; end if;
  insert into public.topics(title,subtitle,category,status,origin,proposed_by,source_url,score_low_label,score_high_label)
  values(s.title,s.subtitle,s.category,'live','community',s.user_id,s.source_url,s.score_low_label,s.score_high_label) returning id into published;
  insert into public.topic_targets(topic_id,id,label) values(published,'match',s.title);
 elsif p_action='duplicate' then
  select id into published from public.topics where id=p_topic_id and status in ('live','closed');
  if published is null then raise exception '연결할 공개 토픽을 선택해 주세요.'; end if;
 end if;
 update public.topic_submissions set status=p_action,review_reason=nullif(btrim(p_reason),''),reviewed_by=p_reviewer,
 reviewed_at=now(),updated_at=now(),revision=revision+1,topic_id=published where id=p_id returning * into s;
 insert into public.topic_submission_notifications(user_id,submission_id,revision,status,title,reason,topic_id)
 values(s.user_id,s.id,s.revision,s.status,s.title,s.review_reason,s.topic_id);
 return s;
end $$;
revoke all on function public.review_topic_proposal(uuid,integer,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.review_topic_proposal(uuid,integer,text,text,text,uuid) to service_role;

alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check(target_type in ('post','comment','guestbook','user','world_score','topic'));

-- Public reads and cached-detail writes must honor hidden topics and blocks.
drop policy topics_read_live on public.topics;
create policy topics_read_live on public.topics for select using(status in ('live','closed') and not exists(
 select 1 from public.blocks b where b.blocker_id=auth.uid() and b.blocked_id=topics.proposed_by));
create or replace view public.topics_feed as
select t.id,t.category,t.title,t.subtitle,t.cover_emoji,t.status,t.created_at,
 coalesce(s.posts_count,0) as posts_count,coalesce(s.global_score,0) as global_score,
 coalesce(s.score_delta,0) as score_delta,coalesce(s.last_activity_at,t.created_at) as last_activity_at,
 t.origin,t.proposed_by,t.source_url,t.score_low_label,t.score_high_label,p.username as proposer_name
from public.topics t left join public.topic_stats s on s.topic_id=t.id
left join public.profiles p on p.id=t.proposed_by
where t.status in ('live','closed') and not exists(select 1 from public.blocks b where b.blocker_id=auth.uid() and b.blocked_id=t.proposed_by);
drop policy world_scores_read on public.world_scores;
create policy world_scores_read on public.world_scores for select using(not is_hidden
 and exists(select 1 from public.topics t where t.id=topic_id and t.status in ('live','closed'))
 and not exists(select 1 from public.blocks b where b.blocker_id=auth.uid() and b.blocked_id=world_scores.user_id));

create function public.guard_world_score_topic() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.topics;
begin
 -- Operators retain the ability to moderate existing scores.
 if current_setting('role',true) in ('authenticated','anon') then
  select * into t from public.topics where id=new.topic_id;
  if t.id is null or t.status<>'live' or exists(select 1 from public.profiles where id=auth.uid() and is_banned)
   or exists(select 1 from public.blocks where blocker_id=auth.uid() and blocked_id=t.proposed_by) then
   raise exception '현재 참여할 수 없는 토픽입니다.' using errcode='42501'; end if;
  if t.origin='community' and new.target_id<>'match' then raise exception '올바르지 않은 채점 대상입니다.'; end if;
 end if;
 return new;
end $$;
create trigger guard_world_score_topic before insert or update on public.world_scores for each row execute function public.guard_world_score_topic();

-- Published questions and score anchors cannot silently change after participation.
create function public.guard_published_topic_content() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if old.origin='community' and exists(select 1 from public.world_scores where topic_id=old.id)
 and (old.title,old.subtitle,old.score_low_label,old.score_high_label) is distinct from
 (new.title,new.subtitle,new.score_low_label,new.score_high_label) then raise exception '참여가 있는 토픽의 질문과 점수 기준은 변경할 수 없습니다.'; end if;
 return new;
end $$;
create trigger guard_published_topic_content before update on public.topics for each row execute function public.guard_published_topic_content();
-- Report resolution and hiding happen atomically; operators only.
create function public.resolve_topic_report(p_id uuid,p_hide boolean) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.reports;
begin
 select * into r from public.reports where id=p_id and target_type='topic' for update;
 if not found then raise exception '토픽 신고를 찾을 수 없습니다.'; end if;
 if r.status<>'open' then return; end if;
 if p_hide then update public.topics set status='hidden' where id=r.target_id; end if;
 update public.reports set status=case when p_hide then 'actioned' else 'dismissed' end where id=p_id;
end $$;
revoke all on function public.resolve_topic_report(uuid,boolean) from public,anon,authenticated;
grant execute on function public.resolve_topic_report(uuid,boolean) to service_role;
commit;
