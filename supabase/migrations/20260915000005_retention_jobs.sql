begin;
alter table public.reports add column closed_at timestamptz;
create function public.stamp_report_resolution() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if new.status<>'open' and old.status='open' then new.closed_at:=now(); end if;
 return new;
end $$;
create trigger stamp_report_resolution before update on public.reports for each row execute function public.stamp_report_resolution();
-- Install scheduled cleanup on Supabase; tests can run the function directly.
do $$
begin
 if exists(select 1 from pg_available_extensions where name='pg_cron') then
  create extension if not exists pg_cron;
  perform cron.schedule('scoor-retention-cleanup','17 3 * * *','select public.purge_expired_content(); delete from public.reports where closed_at < now()-interval ''30 days'';');
 else
  raise notice 'pg_cron unavailable: production deployment must install the retention schedule.';
 end if;
end $$;
commit;
