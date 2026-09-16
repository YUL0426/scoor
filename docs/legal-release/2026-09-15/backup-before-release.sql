-- Migration recovery snapshot in the same database; not disaster recovery.
-- No existing table is changed. The schema is excluded from the Data API.
begin isolation level repeatable read;
create schema scoor_release_backup_20260915;
revoke all on schema scoor_release_backup_20260915 from public, anon, authenticated, service_role;
create table scoor_release_backup_20260915.manifest(table_name text primary key, row_count bigint, captured_at timestamptz not null default now());
do $$
declare r record; n bigint;
begin
 for r in select tablename from pg_tables where schemaname='public' order by tablename loop
  execute format('create table scoor_release_backup_20260915.%I as table public.%I',r.tablename,r.tablename);
  execute format('select count(*) from scoor_release_backup_20260915.%I',r.tablename) into n;
  insert into scoor_release_backup_20260915.manifest(table_name,row_count) values(r.tablename,n);
 end loop;
end $$;
create table scoor_release_backup_20260915.migration_history as table supabase_migrations.schema_migrations;
create table scoor_release_backup_20260915.function_definitions as
 select p.proname, pg_get_function_identity_arguments(p.oid) arguments, pg_get_functiondef(p.oid) definition
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind in ('f','p');
create table scoor_release_backup_20260915.trigger_definitions as
 select c.relname,pg_get_triggerdef(t.oid) definition from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal;
create table scoor_release_backup_20260915.policy_definitions as select * from pg_policies where schemaname='public';
create table scoor_release_backup_20260915.index_definitions as select * from pg_indexes where schemaname='public';
revoke all on all tables in schema scoor_release_backup_20260915 from public, anon, authenticated, service_role;
do $$ declare r record; begin for r in select tablename from pg_tables where schemaname='scoor_release_backup_20260915' loop execute format('alter table scoor_release_backup_20260915.%I enable row level security',r.tablename); end loop; end $$;
commit;
select table_name,row_count,captured_at from scoor_release_backup_20260915.manifest order by table_name;
