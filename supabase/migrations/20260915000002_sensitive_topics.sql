begin;
alter table public.topics add column requires_sensitive_consent boolean not null default false;
create table public.sensitive_consent_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references public.profiles on delete cascade,
 version text not null, accepted boolean not null,
 recorded_at timestamptz not null default clock_timestamp(),
 request_id uuid not null, unique(user_id,request_id)
);
alter table public.sensitive_consent_events enable row level security;
create policy sensitive_read_own on public.sensitive_consent_events for select to authenticated using(user_id=auth.uid());
revoke all on public.sensitive_consent_events from public,anon,authenticated;
grant select on public.sensitive_consent_events to authenticated;
grant all on public.sensitive_consent_events to service_role;
grant usage,select on sequence public.sensitive_consent_events_id_seq to service_role;
create function public.has_sensitive_consent() returns boolean language sql volatile security definer set search_path=public,pg_temp as $$
 select public.has_required_consent() and coalesce((select accepted and version='2026-09-15.1' from public.sensitive_consent_events where user_id=auth.uid() order by id desc limit 1),false)
$$;
revoke all on function public.has_sensitive_consent() from public,anon;
grant execute on function public.has_sensitive_consent() to authenticated;
create function public.set_sensitive_consent(p_accepted boolean,p_version text,p_request_id uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_version is distinct from '2026-09-15.1' or p_request_id is null or p_accepted is null then raise exception 'Unknown notice' using errcode='22023'; end if;
 perform 1 from public.profiles where id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 if p_accepted and not public.has_required_consent() then raise exception 'Required consent missing' using errcode='42501'; end if;
 insert into public.sensitive_consent_events(user_id,version,accepted,request_id) values(auth.uid(),p_version,p_accepted,p_request_id)
 on conflict(user_id,request_id) do nothing;
 if not p_accepted then
  delete from public.world_scores where user_id=auth.uid() and topic_id in (select id from public.topics where category='politics' or requires_sensitive_consent);
 end if;
end $$;
revoke all on function public.set_sensitive_consent(boolean,text,uuid) from public,anon;
grant execute on function public.set_sensitive_consent(boolean,text,uuid) to authenticated;
create function public.check_sensitive_topic() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.role()='authenticated' and exists(select 1 from public.topics where id=new.topic_id and (category='politics' or requires_sensitive_consent))
 and not public.has_sensitive_consent() then raise exception 'SENSITIVE_CONSENT_REQUIRED' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function public.check_sensitive_topic() from public;
create trigger sensitive_before_world before insert or update on public.world_scores for each row execute function public.check_sensitive_topic();
notify pgrst,'reload schema';
commit;
