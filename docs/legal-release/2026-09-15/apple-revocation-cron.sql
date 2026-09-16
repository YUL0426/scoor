-- Apply 20260915000006_secure_apple_retries.sql and deploy the matching handler first.
-- No server key, Vault export, or persistent worker credential is required.
begin;
do $$
begin
  if has_table_privilege('anon','net.http_request_queue','SELECT')
     or has_table_privilege('authenticated','net.http_request_queue','SELECT')
     or has_table_privilege('anon','net._http_response','SELECT')
     or has_table_privilege('authenticated','net._http_response','SELECT') then
    raise exception 'pg_net queue access must be restricted before scheduling';
  end if;
end;
$$;
select cron.schedule(
  'scoor-apple-revocation-retry', '23 * * * *',
  'select public.enqueue_apple_revocation_retry();'
);
commit;
select jobname, schedule, active from cron.job where jobname='scoor-apple-revocation-retry';
