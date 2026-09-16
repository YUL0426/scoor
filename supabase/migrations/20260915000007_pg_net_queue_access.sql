begin;
-- On hosted projects with supabase_admin ownership, Support must apply the
-- grants/revokes as that owner. The postcondition turns silent no-ops into errors.
grant select, insert, update, delete on net.http_request_queue, net._http_response to postgres, service_role;
grant usage, select on all sequences in schema net to postgres, service_role;
do $$
begin
  if exists(select 1 from pg_roles where rolname='supabase_functions_admin') then
    grant select, insert, update, delete on net.http_request_queue, net._http_response to supabase_functions_admin;
    grant usage, select on all sequences in schema net to supabase_functions_admin;
  end if;
end;
$$;
revoke all on net.http_request_queue, net._http_response from public, anon, authenticated;
revoke all on all sequences in schema net from public, anon, authenticated;
do $$
begin
  if has_table_privilege('anon','net.http_request_queue','SELECT')
     or has_table_privilege('authenticated','net.http_request_queue','SELECT')
     or has_table_privilege('anon','net._http_response','SELECT')
     or has_table_privilege('authenticated','net._http_response','SELECT') then
    raise exception 'pg_net ACL unchanged: the owning role must apply this migration';
  end if;
end;
$$;
commit;
