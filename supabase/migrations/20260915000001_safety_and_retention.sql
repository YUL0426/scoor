-- Content checks apply on the server, including direct REST requests.
begin;
create function public.contains_unsafe_content(p_text text) returns boolean
language sql immutable set search_path=public,pg_temp as $$
 select coalesce(p_text,'') ~* '(kill[[:space:]]+yourself|go[[:space:]]+kill[[:space:]]+yourself|child[[:space:]]+porn|n[i1]gg[e3]r|f[a4]gg[o0]t|죽어[[:space:]]*버려|자살[[:space:]]*(해|하라)|아동[[:space:]]*포르노|씨발|시발놈|개새끼)'
$$;
revoke all on function public.contains_unsafe_content(text) from public;
create function public.enforce_content_safety() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare content text;
begin
 if to_jsonb(new)->>'deleted_at' is not null then return new; end if;
 if tg_table_name='topic_submissions' and to_jsonb(new)->>'status'='withdrawn' then return new; end if;
 content:=case tg_table_name when 'posts' then to_jsonb(new)->>'message'
 when 'comments' then to_jsonb(new)->>'text' when 'world_scores' then to_jsonb(new)->>'comment'
 when 'profiles' then concat_ws(' ',to_jsonb(new)->>'username',to_jsonb(new)->>'bio')
 else concat_ws(' ',to_jsonb(new)->>'title',to_jsonb(new)->>'subtitle',to_jsonb(new)->>'score_low_label',to_jsonb(new)->>'score_high_label') end;
 if public.contains_unsafe_content(content) then
  raise exception '게시할 수 없는 표현이 포함되어 있어요. 내용을 수정해 주세요. / Please remove abusive or prohibited content.' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function public.enforce_content_safety() from public;
create trigger safety_before_posts before insert or update on public.posts for each row execute function public.enforce_content_safety();
create trigger safety_before_comments before insert or update on public.comments for each row execute function public.enforce_content_safety();
create trigger safety_before_world before insert or update on public.world_scores for each row execute function public.enforce_content_safety();
create trigger safety_before_proposals before insert or update on public.topic_submissions for each row execute function public.enforce_content_safety();
create trigger safety_before_profiles before insert or update on public.profiles for each row execute function public.enforce_content_safety();

-- Scrub content immediately; retain only synchronization/relationship markers.
create function public.scrub_deleted_content() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.deleted_at is null then return new; end if;
 if tg_table_name='scores' then new.value:=0; new.reason:=null; new.mood:=null;
 elsif tg_table_name='posts' then
  new.message:='[deleted]'; new.score:=0; new.primary_mood:='calm'; new.extra_moods:='{}';
  new.weather:=null; new.country_code:=null; new.city:=null;
 elsif tg_table_name='comments' then new.text:='[deleted]'; end if;
 return new;
end $$;
revoke all on function public.scrub_deleted_content() from public;
-- After consent/LWW guards so deletion cannot hide unrelated content mutations.
create trigger zz_scrub_scores before insert or update on public.scores for each row execute function public.scrub_deleted_content();
create trigger zz_scrub_posts before insert or update on public.posts for each row execute function public.scrub_deleted_content();
create trigger zz_scrub_comments before insert or update on public.comments for each row execute function public.scrub_deleted_content();
create function public.unshare_deleted_score() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.deleted_at is not null then
  update public.posts set deleted_at=new.deleted_at where author_id=new.user_id and source_day=new.day and deleted_at is null and not is_official;
 end if;
 return new;
end $$;
revoke all on function public.unshare_deleted_score() from public;
create trigger unshare_deleted_score after insert or update on public.scores for each row execute function public.unshare_deleted_score();

-- A user's accepted topic remains their authored content when deleting an account.
create function public.remove_authored_topics() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 delete from public.topics where proposed_by=old.id;
 return old;
end $$;
revoke all on function public.remove_authored_topics() from public;
create trigger remove_authored_topics before delete on public.profiles for each row execute function public.remove_authored_topics();

create function public.purge_expired_content() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 delete from public.comments where deleted_at < now()-interval '30 days';
 delete from public.posts where deleted_at < now()-interval '30 days';
 delete from public.topic_submissions where status in ('withdrawn','rejected','duplicate') and updated_at < now()-interval '30 days';
 -- Scores keep a minimal tombstone while the account exists to reject old offline writes.
 update public.scores set value=0,reason=null,mood=null where deleted_at is not null and (value<>0 or reason is not null or mood is not null);
 update public.posts set message='[deleted]',score=0,primary_mood='calm',extra_moods='{}',weather=null,country_code=null,city=null
 where deleted_at is not null and message<>'[deleted]';
 update public.comments set text='[deleted]' where deleted_at is not null and text<>'[deleted]';
end $$;
revoke all on function public.purge_expired_content() from public,anon,authenticated;
grant execute on function public.purge_expired_content() to service_role;
notify pgrst,'reload schema';
commit;
