begin;
-- Service-role only. No FK: cleanup must survive deletion of the user account.
create table public.apple_revocation_queue (
 id uuid primary key default gen_random_uuid(),
 refresh_token text,
 status text not null check(status in ('pending','needs_authorization')),
 created_at timestamptz not null default now(),
 attempts integer not null default 0,
 last_attempt_at timestamptz
);
alter table public.apple_revocation_queue enable row level security;
revoke all on public.apple_revocation_queue from public,anon,authenticated;
grant all on public.apple_revocation_queue to service_role;
comment on table public.apple_revocation_queue is 'Restricted Apple token revocation outbox. Remove immediately after successful revocation; never log token values.';
commit;
