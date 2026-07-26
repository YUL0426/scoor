-- 0004_grants.sql — PostgREST 롤 권한 부여
--
-- RLS만으로는 접근이 되지 않는다. 두 겹이 모두 필요하다:
--   GRANT = 이 롤이 이 테이블을 건드릴 수 있는가 (거친 문)
--   RLS   = 그중 어떤 '행'을 볼 수 있는가 (촘촘한 체)
-- GRANT가 없으면 정책이 아무리 맞아도 42501(permission denied)로 전부 막힌다.
--
-- 0001~0003이 이 부분을 빠뜨려 배포 직후 모든 테이블이 401을 반환했다.
-- (로컬 검증에서는 테스트 하네스가 전 테이블에 grant를 뿌려 이 구멍을 가렸다.)

grant usage on schema public to anon, authenticated;

-- 공개 읽기 — 게스트 모드(§6.2)에서 비로그인 사용자도 World를 둘러본다.
grant select on public.topics             to anon, authenticated;
grant select on public.topic_targets      to anon, authenticated;
grant select on public.topic_stats        to anon, authenticated;
grant select on public.topic_region_stats to anon, authenticated;
grant select on public.profiles           to anon, authenticated;
grant select on public.world_scores       to anon, authenticated;

-- world_scores 읽기 정책이 blocks를 참조한다. 정책 표현식은 호출한 롤의 권한으로
-- 평가되므로, blocks에 select 권한이 없으면 world_scores 읽기 자체가 실패한다.
-- anon에게 열어도 안전하다 — blocks의 RLS가 `blocker_id = auth.uid()`라
-- auth.uid()가 null인 anon은 어차피 0행을 본다.
grant select on public.blocks to anon, authenticated;

-- 로그인 사용자의 쓰기.
grant insert, update, delete on public.blocks               to authenticated;
grant select, insert, update, delete on public.scores       to authenticated;
grant insert, update, delete on public.world_scores         to authenticated;
grant update on public.profiles                             to authenticated;
grant select, insert, update on public.guideline_acceptances to authenticated;

-- 신고는 넣기만 하고 되읽지 못한다. select를 주지 않는 것이 그 자체로 방어선이다
-- (RLS에도 select 정책이 없다 — 조회는 어드민 service_role 전용).
grant insert on public.reports to authenticated;

-- 앞으로 추가될 테이블이 같은 구멍에 빠지지 않도록 기본 권한을 설정한다.
-- Supabase가 관리형 프로젝트에 넣어주는 것과 같은 설정이며, 새 테이블도
-- RLS(0001~0003에서 전부 enable)로 보호되므로 노출 위험은 없다.
alter default privileges in schema public
  grant select on tables to anon, authenticated;
alter default privileges in schema public
  grant insert, update, delete on tables to authenticated;
