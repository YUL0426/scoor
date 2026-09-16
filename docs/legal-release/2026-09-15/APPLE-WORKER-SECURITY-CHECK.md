# Apple 폐기 예약 작업 보안 확인 — 2026-09-15

## 수정 후 상태

서버 키를 SQL/Vault/예약 헤더로 전달하던 경로를 제거하고 account-delete 운영 버전 6으로 배포했다. 마이그레이션 20260915000006 적용 완료. 아래 최초 감사에서 발견한 키 취급과 상태 혼동은 수정했으며, pg_net 관리 객체의 권한 변경만 Supabase 측 작업이 남았다. 자동 예약은 활성화하지 않았다.

- 예약은 DB가 생성한 32바이트 난수의 5분 유효·1회용 인증값을 사용한다. DB에는 SHA-256 해시만 저장한다. 서버 API 키를 내보내거나 Vault에 복제하지 않는다. 함수 내부의 기존 Supabase 자격증명은 그대로 내부 DB 접근에만 사용한다.
- 최초 처리 상태는 in_progress이며, 실패를 관측한 뒤에만 retry_pending으로 바뀐다. 성공 시 토큰을 비우고 행을 삭제한다. needs_authorization과 outcome_unknown은 자동 재시도하지 않는다.
- retry_pending 중 재시도 시각이 지난 건만 최대 10개를 FOR UPDATE SKIP LOCKED로 가져온다. retrying 상태와 lease를 원자적으로 발급하고, 완료에도 동일 lease를 요구한다. 실패 시 1시간 뒤 재시도한다. 중단된 최초 처리/만료 lease는 outcome_unknown으로 격리해 관리자 확인을 기다린다.
- 정상 nonce 인증은 운영 HTTP 200/completed=0, 재사용·만료 nonce는 403, 무인증은 401, 잘못된 형식은 403으로 검증했다. 합성 nonce 해시만 잠시 등록하고 삭제했으며 실제 계정 삭제나 Apple 폐기는 시험하지 않았다.
- 함수 테스트 16개, 로컬 DB 상태/권한 검사, 운영 DB 상태/nonce/실행 차단 롤백 검사가 통과했다. 애플리케이션 예외는 고정 메시지로 처리해 SDK 오류 원문을 로그/응답에 전달하지 않는다.

### 남은 권한 제약

운영 net 스키마와 큐 테이블의 소유자는 supabase_admin이다. postgres는 해당 역할의 멤버가 아니고 GRANT OPTION도 없어 REVOKE가 경고만 내고 실제 ACL은 그대로였다. 이를 성공으로 처리하지 않았다.

- `20260915000007_pg_net_queue_access.sql`은 소유자 실행용으로 준비했다. 신뢰하는 서버/웹훅 역할 접근을 보존하고 PUBLIC/anon/authenticated 접근을 제거하며, 변경이 안 되면 오류를 내도록 했다. 운영 미적용.
- enqueue 함수와 cron 생성 SQL 모두 일반 역할의 큐 SELECT가 남아 있으면 실패한다. 이 제약이 해결될 때까지 nonce조차 pg_net에 넣지 않는다.
- 지원 요청 초안은 `SUPABASE-PG-NET-PERMISSIONS-REQUEST.md`에 준비했으며 외부로 보내지 않았다.
- 예전 키 저장 스크립트는 퇴역 처리했다. 이전 Vault 저장 승인 요청은 더 이상 현재 구현에 필요하지 않다.

---

## 최초 감사 기록 — 수정 전

당시 결론: 서버 키 저장·예약 실행안을 그대로 적용하지 않는다. 함수의 예약 분기는 계정 삭제를 호출하지 않지만, 키 취급과 재시도 대상의 상태 구분은 추가 수정이 필요했다.

## 확인한 범위

- 운영 account-delete 버전 5의 로컬 배포 소스, 예약 SQL, CLI 저장 스크립트 검토.
- 키 값·요청 헤더·사용자 데이터 없이 운영 DB 권한과 로그 설정만 조회.
- 해당 이름의 Vault 키 0개, Apple 재시도 예약 0개, pending 대기열 0건 확인. 이번 감사에서 키 저장이나 예약 생성은 실행하지 않았다.
- 함수 테스트 12개 통과. 추가 검사는 본문에 타인 ID/삭제 지시/Apple 코드를 넣어도 예약 분기가 이를 무시하는지, needs_authorization 제외, 최대 10건 처리, 오류에 테스트용 키가 포함돼도 애플리케이션 로그·응답에 출력하지 않는지를 포함한다.

## 충족하는 항목

- 예약 SQL 자체는 Vault의 이름을 참조하며 실제 서버 키를 포함하지 않는다.
- 예약 분기는 apple_revocation_queue의 pending 항목만 조회하고 Apple /auth/revoke만 호출한다. 성공한 큐 행을 지우거나 실패 횟수를 갱신한 후 반환한다. 사용자 조회/계정 삭제 경로로 내려가지 않는다.
- 예약 분기의 응답은 completed 건수 또는 고정된 오류 메시지다. 자체 console 로그는 고정 문구, HTTP 상태, 큐 UUID이며 요청 헤더·서버 키·Apple 토큰 원문을 출력하지 않는다.
- Vault와 Apple 토큰 큐는 anon/authenticated 역할에서 읽을 수 없다.

## 충족하지 못하거나 추가 검증이 필요한 항목

1. **초기 저장 SQL의 키 리터럴**: 기존 CLI 스크립트는 vault.create_secret 호출 및 값 대조 SQL에 키 문자열을 삽입한다. 화면 출력은 숨기지만, SQL 실행 오류 때 원문이 서버 로그에 기록될 수 있다. 운영 log_min_error_statement=error, log_statement=ddl, log_parameter_max_length=-1, log_parameter_max_length_on_error=0, pgaudit.log=none, pgaudit.log_parameter=off를 확인했다. 따라서 모든 실행 로그에서 비노출이라고 보장할 수 없다.
2. **Vault 밖 요청 큐**: pg_net은 전송 전 HTTP 헤더를 net.http_request_queue에 저장한다. 현 예약안의 apikey 값도 이 단계에서 복호화된 상태로 존재한다. 운영에서 anon/authenticated 모두 net 스키마 USAGE와 요청 큐 SELECT가 true이며 해당 테이블의 RLS는 false다. 일반 REST API로 실제 접근 가능한지는 이번 조회로 확정하지 않았다. 그래도 DB 권한 차원에서 제한되지 않은 헤더 큐에 관리 키를 넣어서는 안 된다.
3. **실패 확정 건만이라는 조건**: 현재 코드는 최초 Apple 폐기 요청 전에 복구용 토큰을 pending 상태로 넣는다. 따라서 첫 시도가 진행되는 짧은 구간도 예약 조회 대상이 될 수 있다. pending 조건만으로 '실패가 확정된 건만'이라고 단정할 수 없다. 최초 처리 중 상태와 재시도 상태를 구분하고, 중복 처리 방지 및 중단된 처리 복구 기준이 필요하다.
4. **플랫폼 로그**: 자체 함수 로그/응답의 비노출 검사는 통과했다. Supabase 게이트웨이·인프라 전체의 헤더 수집/마스킹까지 검증한 것은 아니다. 실제 관리 키를 사용한 시험 호출은 하지 않았다.

## 재개 조건

- 기존 서버 관리 키를 예약 HTTP 헤더에 직접 전달하는 방식부터 재검토한다. 재시도 기능만 허용하는 전용 인증 수단을 사용하면 예약 호출에 DB 관리 키를 전달할 필요가 없다.
- 요청 큐의 일반 API 역할 읽기를 차단하고, 저장 과정의 SQL 원문/매개변수·CLI 추적·오류 로그에 키가 기록되지 않는 전달 경로를 검증한다.
- 최초 시도와 실패 후 재시도를 구분하고 동시에 같은 건을 처리하지 못하도록 수정·테스트한다.
- 수정된 구체 실행안으로 기존 승인 요청을 갱신한 뒤에만 비밀값 저장 및 예약 생성을 진행한다. 기존 스크립트의 provision 모드는 감사 결과에 따라 차단했다.

근거: [pg_net 공식 문서](https://supabase.com/docs/guides/database/extensions/pg_net), [함수 로그 공식 문서](https://supabase.com/docs/guides/functions/logging), 운영 DB의 권한/설정 조회 및 로컬 테스트 결과.
