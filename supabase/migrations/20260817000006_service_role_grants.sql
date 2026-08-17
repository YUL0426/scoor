-- 0006_service_role_grants.sql — 어드민(service_role) 권한 부여
--
-- 0004가 anon/authenticated만 챙기고 service_role을 빠뜨렸다. 같은 파일이
-- "신고 조회는 어드민 service_role 전용"이라고 적어두고 정작 그 롤에는 아무
-- 권한도 주지 않았다. 어드민에서 토픽을 만들면 42501 permission denied가 난다.
--
-- service_role은 RLS를 우회하지만 GRANT까지 우회하지는 않는다 — 0004 서두의
-- "GRANT는 거친 문, RLS는 촘촘한 체"가 이번엔 service_role에 그대로 적용됐다.
-- 게다가 이 프로젝트는 신규 클라우드 기본값(새 엔티티를 Data API 롤에 자동
-- 노출하지 않음, config.toml 참조)이라 명시적 GRANT 없이는 아무것도 안 된다.
--
-- 범위를 좁히지 않고 public 전체를 주는 이유: service_role은 설계상 전권 롤이고
-- (Supabase 관리형 프로젝트의 기본 설정도 이와 같다), 서버 전용이라 클라이언트
-- 번들에 절대 닿지 않는다. 어드민이 앞으로 신고·프로필 화면을 붙일 때 같은
-- 구멍에 다시 빠지지 않게 하려는 목적도 있다.

grant usage on schema public to service_role;

grant all privileges on all tables    in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all functions in schema public to service_role;

-- 앞으로 추가될 테이블도 자동으로 포함되게 한다 (0004가 anon/authenticated에
-- 대해 해둔 것과 같은 처리).
alter default privileges in schema public grant all on tables    to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant all on functions to service_role;
