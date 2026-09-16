# Scoor 제출 전 점검 — 2026-09-15

주요 코드·운영 DB 수정과 서명된 아카이브 생성은 완료했다. 아래 운영 설정과 실제 인증/삭제 검증이 남아 있으므로 아직 심사 제출 완료 상태는 아니다. 이 보고서는 최초 점검 결과를 대체한다.

## 2026-09-16 출시 범위 결정

사용자 결정에 따라 pg_net 자동 재시도는 비활성화하고 출시 준비는 별도로 진행한다. pg_net 권한 지원 요청 자체는 **자동 재시도 활성화의 차단 사항**이며, 일반 계정 삭제/최초 Apple 토큰 폐기 경로의 기술적 출시 차단 사항은 아니다. 이 경로는 Edge Function에서 Apple REST API를 직접 호출하며 pg_net/cron/enqueue를 사용하지 않는다.

Apple의 계정 삭제 안내는 앱 내 계정 삭제와 Sign in with Apple 토큰 폐기를 요구하지만 특정 예약 시스템이나 매시간 자동 재시도를 명시하지 않는다. 따라서 Supabase 지원 답변만을 기다리며 출시 전체를 멈출 필요는 없다는 판단이다. 다만 실제 Apple 시험 계정의 로그인→삭제→토큰 폐기 검증은 여전히 출시 전 확인 항목이다. 자동 재시도가 꺼진 동안 발생할 실패 건을 확인하고 수동 재처리/후속 조치할 운영 절차도 필요하다. 현재 정책은 실패한 Apple 폐기 건을 재처리한다고 안내하므로, 실패 건을 대기열에 무기한 방치하는 운영은 이 판단에 포함되지 않는다.

지원 요청은 초안만 작성했으며 외부 발송하지 않았다. 지원 측 권한 조정과 실제 ACL/예약 호출 검증이 끝나기 전에는 자동 예약을 켜지 않는다. 이 분류는 SMTP, 계약/지역 신고, 최종 인증 검증 등 다른 미완료 항목을 해소한 것으로 간주하지 않는다.

## 완료

- 가입 약관에 서비스 운영을 위한 비독점 콘텐츠 라이선스를 포함하고 게시할 때마다 별도 라이선스 체크를 요구하지 않도록 간소화했다. 개인정보 및 지정 민감정보 동의는 구분한다.
- 동의 전 조회 실패를 저장 실패처럼 표시하지 않도록 수정했다. 조회/저장 요청 경합 및 폼 재생성으로 선택이 초기화되는 문제를 해결하고 재시도 후 화면 이동을 UI 테스트했다.
- 운영 DB `ebxdbadcejbytixumxrj`에 누락된 마이그레이션 9개를 적용했다. 동의, 토픽 제안, 민감정보 동의, Apple 폐기 대기열 및 삭제/보유기간 정리를 포함한다.
- 적용 전 비공개 복구 스키마에 앱 테이블 11개와 함수·정책·트리거 등 복구 자료를 보관했다. 원본 행 대조 및 임시 테이블 복원 검사 성공, API 역할 접근 차단과 RLS 확인. 전체 Auth/클러스터 백업이나 외부 장애 복구 백업은 아니다.
- 복구본은 사용자 승인에 따라 24시간 보관한다. `scoor-release-snapshot-cleanup`이 2026-09-16 00:45 KST에 복구 스키마와 자신의 예약을 삭제하도록 설정돼 있다. 실제 예약 실행 결과는 아직 확인 전이다.
- 서버 삭제 반영 시 본문·점수·감정 내용을 제거하고 연결된 홈 공유를 해제한다. 계정 유지 중 최소 동기화 표식만 보존한다. 삭제된 글/댓글 관계 표식, 철회/반려 제안 및 종료 신고의 30일 정리를 매일 12:17 KST에 실행하도록 설정했다.
- 서버 금지 텍스트 필터를 게시물·댓글·World·제안·프로필에 적용했다. 기존 신고/차단 기능과 함께 사용한다. 단순 규칙 필터이므로 모든 유해 표현을 탐지하는 것은 아니며 실제 신고 대응이 계속 필요하다.
- 지정 정치/민감 토픽 참여에 별도 선택 동의를 요구하고, 철회 시 해당 참여 내역을 삭제한다. 일반 일기와 일반 토픽은 계속 이용 가능하다.
- App Privacy 총 8종을 앱 기능 / 사용자와 연결 / 추적 안 함으로 저장·게시했다. 이름, 이메일, 사용자 ID, 기타 사용자 콘텐츠, 민감 정보, 제품 상호 작용, 고객 지원, 기타 진단 데이터다. 코드와 실제 운영 로그 대조 및 사용자 승인을 거쳤고 앱 Privacy Manifest도 맞췄다.
- ASC 연령 등급 16+ 재정의를 승인받아 저장했다. 한국에는 15+, iOS 26 이전 글로벌 등급에는 17+로 환산된다. 앱 약관 기본 가입 연령은 만 14세이며 거주지의 더 높은 기준도 적용한다.
- ASC 콘텐츠 권한을 Yes로 저장했다. 가입 약관 라이선스 및 동의 구조에 근거하며, 이용자가 타인의 권리를 침해하는 게시물을 올릴 가능성까지 해소하는 것은 아니다.
- 공개 Notion 한국어/영어 개인정보처리방침을 앱 정책 2026-09-15.1과 맞췄다. 로그인하지 않은 별도 브라우저에서 새 버전 접근을 확인했다. 국외 이전의 세부 운영 사실 확인은 아래와 같이 남아 있다.
- 영어 스토어 설명/프로모션에 실제 공유·World·댓글·신고·차단을 반영하고 심사 메모에 동의 관리 및 삭제 경로를 적었다.
- 계정 삭제 함수를 운영 버전 6으로 배포했다(ACTIVE). Apple 토큰을 폐기 전에 보관하고 서버 계정 삭제 성공 후에만 앱 세션을 정리한다. 예약 인증은 서버 키 대신 DB가 발급·소비하는 5분 유효 1회용 nonce로 변경했다. 사용자 요청은 Auth.getUser로 검증한다. gateway의 legacy JWT 검사는 함수 내 인증에 맞춰 껐다.
- 추가 마이그레이션 20260915000006 적용 완료. 최초 처리(in_progress), 확인된 실패(retry_pending), 재시도 중(retrying), 결과 불명(outcome_unknown)을 분리하고, 원자적 claim/lease 및 재사용 불가 nonce 검증을 구현했다. 큐 권한이 열려 있으면 예약 요청을 만들지 않는 안전장치도 반영했다.
- 운영 Secrets 화면에서 APPLE_CLIENT_ID, APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY의 저장 해시를 예상 값과 대조했다. 네 항목 모두 일치하며 P8은 다운로드한 AuthKey_N82L8JB3HV.p8과 같다. 비밀키 원문은 보고서에 보관하지 않는다.

## 검증 및 아카이브

- 서명한 iOS 단위 테스트 136개 통과.
- 동의 관련 단위 테스트 9개 및 UI 테스트 2개 통과: 초기 조회 실패, 저장 실패 후 선택 유지, 재시도 후 다음 화면 이동 포함.
- 최신 계정 삭제 함수 테스트 16개 통과. 최초 시도 중 재시도 차단, 상태 저장 실패 시 계정 보존, nonce 재사용/오류 차단, 예약 분기의 계정 삭제 미진입, 최대 10건 처리 및 자체 로그/응답의 비밀값 비노출 포함. 모의 Apple 서비스 결과이며 실제 Apple 폐기 성공 증거는 아니다.
- 신규 보안 SQL의 로컬 DB 검사와 운영 롤백 검사 통과: APPLE_RETRY_SECURITY_TESTS_PASSED. 실제 운영 함수에서도 유효 nonce는 HTTP 200/completed=0, 재사용·만료 nonce는 403, 무인증은 401로 확인했다. 시험 nonce는 삭제했으며 서버 키는 조회·이동하지 않았다.
- 운영 DB의 임시 데이터 + rollback 회귀 검사 성공: PRODUCTION_CONSENT_AND_SAFETY_TESTS_PASSED.
- 서명된 Release archive 생성 성공: `/Users/yul/Desktop/scoor-workspace/release/Scoor-2026-09-15.xcarchive`.
- 실제 번들은 com.euro.Scoor, 1.0, 빌드 2. 정책 SHA-256은 8280caddd9c192134a4c61c898ca944f5ef11e7c02ac08c693866e66c3d0ac3e. Privacy Manifest 8종 및 추적 false 확인.
- 아카이브 업로드와 심사 제출은 실행하지 않았다.

## 제출 전에 남은 작업

1. **Apple 실제 폐기 검증**: Apple Developer에서 N82L8JB3HV가 Sign in with Apple 및 G83W9HD6G7.com.euro.Scoor에 연결됨을 확인했다. 운영 Secrets의 네 설정 해시도 모두 일치한다. Team ID/Client ID는 G83W9HD6G7 / com.euro.Scoor다. 실제 Apple 인증 및 새 시험 계정 삭제를 통한 토큰 폐기는 아직 미검증이다.
2. **Apple 폐기 자동 재시도**: 서버 키 전송 제거·상태 분리·nonce 검증은 운영 반영했다. pg_net 큐는 supabase_admin 소유라 현재 postgres 역할의 REVOKE가 실효가 없다. 소유자 실행용 20260915000007_pg_net_queue_access.sql 및 지원 요청 초안을 준비했으며 운영 적용/외부 발송은 하지 않았다. enqueue와 cron 등록은 실제 ACL 차단 여부를 검사해 미차단 시 실패한다. 따라서 자동 예약은 아직 활성화되지 않았다. 지원 작업 후 ACL과 실제 예약 호출을 검증해야 한다. 상세 상태: docs/legal-release/2026-09-15/APPLE-WORKER-SECURITY-CHECK.md.
3. **이메일 SMTP**: 확인 당시 custom SMTP 꺼짐, 이메일 확인 요구 켜짐. 기본 발송기는 프로젝트 팀 밖 주소에 발송하지 않으므로 일반 사용자 회원가입 준비가 안 된 상태다. SMTP 서비스·발신 주소·자격 증명 설정 및 인증 링크 복귀 검증 필요. 이메일 확인을 끄는 방식으로 우회하지 않았다.
4. **Apple 계약 및 국가별 신고**: ASC Business에서 새 Developer Program 계약 동의 필요와 EU DSA 거래자 상태 미완료를 확인했다. 현재 175개 국가/지역에 EU와 중국 본토도 포함된다. 계정 소유자의 계약 검토/동의, 실제 거래자 여부 결정 및 출시 지역별 요건 확인이 필요하다. 배포 지역이나 거래자 여부를 임의 변경하지 않았다.
5. **국외 이전 상세 고지**: 서울 주 DB와 Supabase/Gmail 사용은 확인했다. 해외 지원·하위 처리업체·메일 처리의 실제 국가, 수신자, 시기/방법, 기간과 적용 근거는 운영 계약/설정에 맞춰 추가 확인해야 한다. 공개 정책 수정이 이 확인을 대신하지 않는다.
6. **최종 제출 검증**: 심사 계정 실제 로그인, Apple/Google 인증 복귀, 새 시험 계정 삭제/잔존 데이터 확인, 아카이브 업로드 및 빌드 연결이 남았다. 심사 계정 이름은 입력돼 있으나 암호 유효성은 미검증이다. scoor.app DNS는 마지막 확인에서 해석되지 않았다. 현재 등록된 지원/개인정보 URL은 열리는 Notion 페이지다.

## 근거 및 운영 링크

- [ASC](https://appstoreconnect.apple.com/apps/6810264505/distribution)
- [운영 Secrets](https://supabase.com/dashboard/project/ebxdbadcejbytixumxrj/functions/secrets)
- [영어 정책](https://app.notion.com/p/Scoor-Privacy-Policy-3d932acbe72080a2bf3ee8faf5932723)
- [한국어 정책](https://app.notion.com/p/Scoor-3d332acbe720805b818cf6a492e886f0)
- [Apple 심사 지침](https://developer.apple.com/app-store/review/guidelines/)
- [Apple 개인정보 신고](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple 계정 삭제](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Sign in with Apple 키](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key)
- [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase 환경 변수](https://supabase.com/docs/guides/functions/secrets)
- [Supabase 예약 호출](https://supabase.com/docs/guides/functions/schedule-functions)
