# Supabase Support 요청 초안 — 발송하지 않음

Subject: Restrict PUBLIC access to pg_net request/response tables (project ebxdbadcejbytixumxrj)

Our hosted project runs pg_net 0.20.4. The net schema, net.http_request_queue and net._http_response are owned by supabase_admin. Their table ACL includes PUBLIC=arwdDxtm/supabase_admin. Both anon and authenticated have SELECT and net schema USAGE; the request queue has no RLS.

Our postgres role is not a member of supabase_admin and has no table/schema grant option. REVOKE runs with a warning but does not change these ACLs. We verified this in a rolled-back transaction.

Please apply the attached 20260915000007_pg_net_queue_access.sql as the owning role, or provide a supported equivalent. It preserves postgres/service_role/trusted webhook access, then removes PUBLIC/anon/authenticated access to the request/response tables and sequences, with a postcondition that fails if client roles retain SELECT.

The project currently has no Apple retry cron enabled. The proposed worker does not transmit server API keys; it uses a five-minute, single-use nonce. Its enqueue function refuses to send even this nonce while client-role SELECT remains enabled. We need the ACL restriction before enabling the schedule.

No access token, server API key, Apple private key, or user data is included in this request.

## 첨부 및 적용 후 순서

1. `supabase/migrations/20260915000007_pg_net_queue_access.sql`을 소유자 역할로 적용하고 마이그레이션 이력을 맞춘다.
2. 일반 역할의 요청/응답 큐 SELECT가 false인지 재확인한다.
3. `docs/legal-release/2026-09-15/apple-revocation-cron.sql`을 적용한다.
4. 빈 큐 상태에서 enqueue 및 HTTP 200 응답을 확인한 뒤 예약 활성 상태를 검증한다.

[Supabase 지원](https://supabase.com/dashboard/support/new)
