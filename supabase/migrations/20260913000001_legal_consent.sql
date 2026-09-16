-- Explicit, versioned consent receipts. No existing user is auto-consented.
-- Terms / privacy notice / essential account processing / age are separate receipts.
begin;
create table public.legal_consent_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references public.profiles(id) on delete cascade,
 kind text not null check(kind in ('terms','privacy_notice','account_data','age','publication')),
 version text not null,
 document_sha256 text not null,
 accepted boolean not null,
 recorded_at timestamptz not null default clock_timestamp(),
 request_id uuid not null,
 language text not null check(language in ('ko','en','legacy')),
 unique(user_id,request_id,kind)
);
create index legal_consent_latest on public.legal_consent_events(user_id,kind,id desc);
alter table public.legal_consent_events enable row level security;
revoke all on public.legal_consent_events from anon,authenticated;
grant select on public.legal_consent_events to authenticated;
create policy legal_receipts_read_own on public.legal_consent_events for select to authenticated using(user_id=auth.uid());
grant all on public.legal_consent_events to service_role;
grant usage,select on sequence public.legal_consent_events_id_seq to service_role;

-- Preserve historical guideline timestamps, but never treat v1 as the new license.
insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,recorded_at,request_id,language)
select user_id,'publication',version,'legacy-unversioned-document',true,accepted_at,gen_random_uuid(),'legacy'
from public.guideline_acceptances;
revoke insert,update,delete on public.guideline_acceptances from anon,authenticated;

create function public.legal_current_for(p_user uuid, p_kind text, p_version text)
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select coalesce((select accepted and version=p_version from public.legal_consent_events
 where user_id=p_user and kind=p_kind order by id desc limit 1),false)
$$;
revoke all on function public.legal_current_for(uuid,text,text) from public,anon,authenticated;

create function public.has_required_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and
 public.legal_current_for(auth.uid(),'terms','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'privacy_notice','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'account_data','2026-09-13.1') and
 public.legal_current_for(auth.uid(),'age','2026-09-13.1')
$$;
revoke all on function public.has_required_consent() from public,anon;
grant execute on function public.has_required_consent() to authenticated;

create function public.has_publication_consent()
returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select public.has_required_consent() and public.legal_current_for(auth.uid(),'publication','2.0')
$$;
revoke all on function public.has_publication_consent() from public,anon;
grant execute on function public.has_publication_consent() to authenticated;

create function public.accept_required_consent(p_version text,p_digest text,p_request_id uuid,p_language text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_version is distinct from '2026-09-13.1' or p_digest is distinct from '9cadf8a69f87962395d986f951f39b4c5fa04d66efbc2f1e0501ebe4c69cc0f6'
 or p_language not in ('ko','en') or p_language is null or p_request_id is null then
 raise exception 'Unknown consent document' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 select auth.uid(),kind,p_version,p_digest,true,p_request_id,p_language
 from unnest(array['terms','privacy_notice','account_data','age']) kind
 on conflict(user_id,request_id,kind) do nothing;
end $$;
revoke all on function public.accept_required_consent(text,text,uuid,text) from public,anon;
grant execute on function public.accept_required_consent(text,text,uuid,text) to authenticated;

create function public.accept_publication_consent(p_version text,p_digest text,p_request_id uuid,p_language text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found or not public.has_required_consent() then raise exception 'Required consent missing' using errcode='42501'; end if;
 if p_version is distinct from '2.0' or p_digest is distinct from '9cadf8a69f87962395d986f951f39b4c5fa04d66efbc2f1e0501ebe4c69cc0f6'
 or p_language not in ('ko','en') or p_language is null or p_request_id is null then
 raise exception 'Unknown publication agreement' using errcode='22023'; end if;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 values(auth.uid(),'publication',p_version,p_digest,true,p_request_id,p_language)
 on conflict(user_id,request_id,kind) do nothing;
 -- A stale retry after withdrawal must not silently restore consent.
 if public.has_publication_consent() then
 insert into public.guideline_acceptances(user_id,version,accepted_at) values(auth.uid(),p_version,clock_timestamp())
 on conflict(user_id) do update set version=excluded.version,accepted_at=excluded.accepted_at;
 end if;
end $$;
revoke all on function public.accept_publication_consent(text,text,uuid,text) from public,anon;
grant execute on function public.accept_publication_consent(text,text,uuid,text) to authenticated;

create function public.withdraw_required_consent(p_request_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 select auth.uid(),kind,case when kind='publication' then '2.0' else '2026-09-13.1' end,
 '9cadf8a69f87962395d986f951f39b4c5fa04d66efbc2f1e0501ebe4c69cc0f6',false,p_request_id,coalesce((select language from public.legal_consent_events where user_id=auth.uid() and kind='terms' order by id desc limit 1),'en')
 from unnest(array['terms','privacy_notice','account_data','age','publication']) kind
 on conflict(user_id,request_id,kind) do nothing;
 delete from public.guideline_acceptances where user_id=auth.uid();
end $$;
revoke all on function public.withdraw_required_consent(uuid) from public,anon;
grant execute on function public.withdraw_required_consent(uuid) to authenticated;

-- Publishing is an optional feature; withdrawing it does not end account use.
create function public.withdraw_publication_consent(p_request_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.legal_consent_events(user_id,kind,version,document_sha256,accepted,request_id,language)
 values(auth.uid(),'publication','2.0','9cadf8a69f87962395d986f951f39b4c5fa04d66efbc2f1e0501ebe4c69cc0f6',false,p_request_id,
 coalesce((select language from public.legal_consent_events where user_id=auth.uid() and kind='terms' order by id desc limit 1),'en'))
 on conflict(user_id,request_id,kind) do nothing;
 delete from public.guideline_acceptances where user_id=auth.uid();
end $$;
revoke all on function public.withdraw_publication_consent(uuid) from public,anon;
grant execute on function public.withdraw_publication_consent(uuid) to authenticated;

-- Owners must be able to mark their own posts deleted after withdrawing.
-- The visibility-only SELECT policy otherwise rejects the updated tombstone.
create policy posts_owner_read_for_removal on public.posts for select to authenticated using(author_id=auth.uid());

-- Enforce consent for direct REST calls and security-definer posting RPCs too.
-- Read, report, block, hard-delete and unchanged-content soft-delete remain possible.
create function public.enforce_submission_consent()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.role() is distinct from 'authenticated' then return new; end if;
 if tg_op='UPDATE' then
   if to_jsonb(new)->>'deleted_at' is not null and
      (to_jsonb(new)-'deleted_at'-'updated_at')=(to_jsonb(old)-'deleted_at'-'updated_at') then return new; end if;
   if tg_table_name='topic_submissions' and to_jsonb(new)->>'status'='withdrawn' and
      (to_jsonb(new)-'status'-'revision'-'updated_at')=(to_jsonb(old)-'status'-'revision'-'updated_at') then return new; end if;
 end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 if not public.has_required_consent() then raise exception 'Required agreements must be accepted before submitting data' using errcode='42501'; end if;
 if tg_table_name in ('posts','comments','world_scores','topic_submissions') and not public.has_publication_consent() then
 raise exception 'Publication agreement must be accepted before posting' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function public.enforce_submission_consent() from public,anon,authenticated;
create trigger consent_before_scores before insert or update on public.scores for each row execute function public.enforce_submission_consent();
create trigger consent_before_posts before insert or update on public.posts for each row execute function public.enforce_submission_consent();
create trigger consent_before_comments before insert or update on public.comments for each row execute function public.enforce_submission_consent();
create trigger consent_before_world before insert or update on public.world_scores for each row execute function public.enforce_submission_consent();
create trigger consent_before_proposals before insert or update on public.topic_submissions for each row execute function public.enforce_submission_consent();
create trigger consent_before_likes before insert or update on public.post_likes for each row execute function public.enforce_submission_consent();

create or replace function public.submit_topic_proposal(p_id uuid, p_title text, p_subtitle text, p_category text,
 p_kind text, p_source_url text, p_low text, p_high text, p_revision integer default null)
returns public.topic_submissions language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.topic_submissions; uid uuid:=auth.uid();
begin
 if uid is null then raise exception '로그인이 필요합니다.' using errcode='42501'; end if;
 -- One lock per account makes limits safe against concurrent requests.
 perform 1 from public.profiles where id=uid and not is_banned for update;
 if not found then raise exception '제안할 수 없는 계정입니다.' using errcode='42501'; end if;
 if not public.has_publication_consent() then
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

notify pgrst, 'reload schema';
commit;
