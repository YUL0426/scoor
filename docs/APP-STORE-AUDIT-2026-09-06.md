# Scoor App Store 최종 점검 — 2026-09-06

## 1. 결론: 출시 보류

개인정보처리방침·약관 운영 URL이 DNS 오류로 열리지 않는다. 실제 공급자 로그인, 운영 계정 삭제/Apple 토큰 폐기, 두 운영 계정 간 격리, App Store Connect 제출 정보는 아직 미검증이다. 아래의 빌드·테스트 성공만으로 출시 가능하다고 판단하지 않는다.

GitHub·Supabase 연결을 재설정하지 않았다. 운영 DB/인증 설정 변경, 테스트 사용자 생성, 함수 배포, Git push/merge, App Store 업로드·제출은 하지 않았다.

## 2. 배포 대상과 직접 확인한 상태

| 항목 | 결과 및 검증 수준 |
|---|---|
| 저장소 | `https://github.com/YUL0426/scoor.git`, 작업 폴더 `scoor-repo` |
| 브랜치 | `feat/release-blockers-2026-08`, 시작 커밋 `efe4ba3bdec708bffbb55af408af660614acf72d`; `git ls-remote`로 원격과 일치 확인. 원격 main `4bcc896`보다 7커밋 앞섬. 수정은 로컬 미커밋 상태 |
| Supabase | CLI 연결 ref와 Release 번들 호스트 모두 `ebxdbadcejbytixumxrj`; 실제 HTTP 요청 성공 |
| 운영 환경변수 | Release Info.plist에서 호스트, 공개 `sb_publishable_` 키, Google client ID 형식 확인. 서버 전용 비밀키는 값 출력 없이 소스와 Release 번들 패턴 검사; service-role JWT·sb_secret·개인키 패턴 발견 없음 |
| Release 빌드 | Xcode 26.6에서 iOS 기기용 Release archive 성공. 기존 Apple Development 인증서로 서명한 archive도 성공 |
| 서명 | `com.euro.Scoor`, 팀 `G83W9HD6G7`; 기존 개발 프로파일 만료 2027-06-22, Apple 로그인 entitlement 포함. `get-task-allow=true`인 개발 서명이다. App Store 배포 서명/export/서버 validation은 **미검증** |
| 버전·아이콘 | 1.0 (1), 최소 iOS 17.0. 아이콘 1024×1024, 알파 없음, 빌드 산출물에 AppIcon·PrivacyInfo.xcprivacy 포함 |
| 공개 Auth 설정 | `/auth/v1/settings` HTTP 200: Apple/Google/email 활성, anonymous_users 비활성, 이메일 확인 필요. 실제 OAuth 및 이메일 수신은 **미검증** |
| 운영 데이터 읽기 | 앱 통합 테스트로 World 토픽 5건 및 반응 읽기 성공. `feed_posts`는 HTTP 200, 공개 글 0건. 기존 체크리스트의 “피드 미적용” 주장을 그대로 사용하지 않았음; 전체 migration 이력은 **미검증** |
| 운영 개인 점수 | 익명 `scores` 조회 HTTP 401 / permission denied. 이는 익명 접근 거부 확인이며, 로그인 계정 간 RLS의 증명은 아님 |
| 삭제 함수 | 읽기 전용 GET 요청에 405 Method not allowed 응답. 삭제 성공이나 현재 배포 코드 일치의 증명은 아님 |
| 관리 권한 | `supabase functions list`가 서비스 권한 403 응답. 서버 시크릿·SMTP·운영 정책/배포 버전 확인은 **미검증** |
| 정책 URL | `https://scoor.app/privacy/ko`, `https://scoor.app/terms/ko` 모두 DNS 해석 실패 |

## 3. 실제 수정 및 재검증

| 발견 문제 | 최소 수정 | 검증 |
|---|---|---|
| 공급자 토큰의 Supabase 교환 실패를 삼키고 로컬 로그인 성공 처리 | 서버 검증 성공 후에만 세션 생성. 토큰 누락/교환 실패는 오류 전달 | 모의 HTTP 401에서 로그인 실패·세션 미생성 회귀 테스트 통과. 실제 Apple/Google 로그인은 **미검증** |
| 서버 세션이 없으면 계정 삭제 호출을 건너뛰고 성공 처리; 만료 토큰 사용 | 삭제 전 유효 토큰 확보/갱신, 없으면 실패 처리 | 토큰 없음 실패, 만료→갱신→새 토큰으로 삭제 요청 순서의 모의 HTTP 테스트 통과 |
| 일시적 인증 서버 오류가 refresh token을 지움; 로그아웃 중 갱신 응답이 세션을 되살릴 수 있음 | 일시 오류에서는 토큰 보존, 갱신 응답 적용 전 기존 세션과 일치 확인, 현재 계정과 다른 저장 토큰 사용 차단 | 503 후 세션/Keychain 보존 테스트 통과. 실제 장시간 세션/동시 요청의 실기기 검증은 **미검증** |
| 오프라인 실패 8회 후 업로드/삭제 대기 기록 소실 | 재시도 가능한 실패에 횟수 제한 삭제 제거; 인증 재요청/앱 업데이트 상태도 보존 | 20회 실패 후 재로드, HTTP 401 후 대기 기록 보존 테스트 통과 |
| 다른 계정의 대기 기록까지 현재 토큰으로 업로드 시도 | 현재 계정 소유 작업만 전송, 중복 push 방지, 계정 변경 시 중단 | A/B 대기 기록 중 B 로그인 시 B만 전송하고 A 보존하는 HTTP 테스트 통과 |
| 공통 동기화 시각과 client_updated_at 필터로 다른 계정의 과거 기록/늦게 올라온 오프라인 기록 누락 | 계정별 필터로 전체 페이지 조회; 소유자 일치 확인 후 병합 | 최근 동기화 시각이 있어도 과거 날짜의 서버 기록·이유를 가져오는 HTTP 테스트 통과. 대용량 실서버 페이지 경계는 **미검증** |
| 계정 삭제가 다른 계정의 로컬 점수·방명록·대기 기록도 삭제 | 삭제한 사용자에 속한 점수/방명록/큐만 제거 | 두 사용자 SwiftData 및 큐 격리 회귀 테스트 통과 |
| 피드 댓글 신고 시 authorId를 nil로 넘겨 차단 선택지가 사라짐 | 서버 댓글 작성자 ID를 도메인 모델과 신고 시트에 연결 | 작성자 ID 전달 회귀 테스트 및 빌드 통과. 실제 로그인 후 신고·차단 쓰기는 **미검증** |
| Release에도 UI 테스트 인증 우회 인자 활성 | `-uitests-reset`을 DEBUG에서만 허용 | Release 컴파일/서명 성공. 실제 Release 실행 인자 주입 테스트는 **미검증** |

동기화 수정의 절충: 운영 스키마를 변경하지 않기 위해 점수 조회는 전체 페이지 방식이다. 기록이 많으면 기존 증분 조회보다 통신량이 증가한다. 재접속 시 동기화 트리거는 기존 포그라운드 복귀·수동 동기화·기록 저장 방식이며, 화면에 머문 상태의 네트워크 복구 즉시 동기화는 **미검증**이다.

## 4. 실행한 테스트와 한계

- 단위·회귀·읽기 통합 테스트: **115개 통과**. 이 중 World 읽기 테스트는 실제 Supabase에 연결하며, 인증/업로드 회귀 테스트는 별도의 URLProtocol 모의 서버를 사용한다.
- UI: iPhone 17 Pro / iOS 26.5 시뮬레이터. 점수 생성·이유 입력, 점수/이유 수정 후 재실행 보존, 기록 상세 조회, Home/Feed/World/My Page 이동 테스트 통과. 공급자 로그인은 DEBUG 모의 인증이므로 실인증 통과로 계산하지 않는다.
- 캘린더 삭제 UI: 확인 대화상자에서 삭제 후 해당 날짜가 새 기록 입력 상태로 돌아오는 것까지 **통과**. 위 3개 UI 시나리오와 합해 선택한 UI 테스트 **4개 통과**(별도 재실행 결과 합산).
- 로컬 PostgreSQL 17: 현재 migration 전체 적용 성공. 기존 피드 RLS 17개 + 추가 점수 RLS 8개 = **25개 통과**. 좋아요/댓글, 신고 관련 차단 필터, 다른 계정 점수 읽기/쓰기/수정/삭제 거부, 오래된 쓰기 충돌, 삭제 tombstone 및 계정 cascade 검증. 임시 DB 종료 완료. **운영 RLS와 동일하다는 보장은 하지 않는다.**
- 최초 무서명 시뮬레이터 실행에서는 Keychain 저장 테스트 1개가 실패했다(2 assertions). 기본 시뮬레이터 서명으로 재실행해 통과했으며, 우회 저장소를 만들거나 제품 Keychain 코드를 약화시키지 않았다.
- 기존 UI 테스트의 수정/삭제 버튼 선택자가 번역 문자열 또는 배경 버튼을 선택해 실패했다. 수정은 기존 접근성 ID, 삭제는 배경 삭제 버튼을 제외하도록 테스트 선택자를 바로잡았다.
- 선택한 실행 경로에서 앱 크래시 없음. 신규 설치→기록→재실행은 확인했으나, 실기기·기존 출시 버전 DB 업그레이드·저장 공간 부족·손상 DB·전체 기종/iPad 회전·장시간 사용은 **미검증**.
- Swift 6 actor isolation 관련 경고가 남아 있다. 현재 프로젝트 Swift 5 모드 빌드는 통과하며, 이 점검에서 대규모 concurrency 리팩터링은 하지 않았다.

재현 자료(현재 Mac의 임시 파일):

- `/tmp/scoor-release-audit-verified-tests.xcresult`, 동명 `.log`: 최종 단위 테스트/삭제 UI
- `/tmp/scoor-release-audit-final-tests.xcresult`, 동명 `.log`: 점수·이유 수정/재실행 및 입력 UI 통과 자료; 삭제 선택자 수정 전 실패도 포함
- `/tmp/scoor-release-audit-signed.xcarchive`, `/tmp/scoor-release-audit-signing.log`: 개발 서명 Release 산출물
- `/tmp/scoor-audit-rls.log`, `/tmp/scoor-audit-score-rls.log`: 격리된 로컬 RLS 결과
- `supabase/tests/score_rls.sql`: 추가 점수 RLS 재현 시나리오(로컬 테스트 DB 전용)

## 5. 제출 전 사용자가 해야 할 작업

1. `scoor.app` DNS/호스팅을 복구하고 앱의 한국어 정책·약관 링크가 실제 콘텐츠로 열리는지 확인한다. [Apple 5.1.1 개인정보처리방침 요건](https://developer.apple.com/app-store/review/guidelines/#privacy)을 기준으로 최종 공개 문서의 수집·보유·삭제 설명도 확인한다.
2. 기존 프로젝트 권한이 있는 콘솔에서 SMTP/이메일 확인 링크, Apple/Google 공급자 설정, Apple 삭제 함수 시크릿·배포 버전을 **확인**한다. 이번에 조회 가능한 피드가 이미 존재하므로 과거 문서만 보고 migration을 재적용하지 않는다.
3. 승인된 테스트 계정 2개와 실기기로 실제 로그인/로그아웃/재실행/만료 후 갱신, 계정 삭제 및 서버 데이터 제거를 검증한다. Apple 계정은 서버 응답의 `apple_revoked`와 Apple 연결 해제도 확인한다. 소스 함수는 폐기 실패를 무시할 수 있으므로 삭제 성공만으로 폐기 성공을 판단하면 안 된다. [Apple 계정 삭제 안내](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
4. 같은 두 계정으로 오프라인 생성·수정·삭제 → 재접속 → 다른 기기 조회, 게스트 기록 이전, 계정 전환 시 기록 비노출, 실제 좋아요·댓글·신고·차단을 검증한다. 운영 테스트 데이터 변경은 사전 승인된 범위에서만 진행한다.
5. App Store Connect의 App Privacy 실제 답변과 수집 항목을 대조한다. 번들 선언은 이메일/사용자 ID/기타 사용자 콘텐츠, 앱 기능 목적·추적 없음이다. 앱의 점수·이유·닉네임/소개·댓글·신고/차단, 공급자가 전달·보관하는 이름 등 메타데이터와 좋아요 등 상호작용을 포함해 누락 여부를 확인해야 한다. 현재 신고 답변에 접근하지 못했으므로 일치 여부는 **미검증**이다. [Apple App Privacy 분류](https://developer.apple.com/app-store/app-privacy-details/).
6. 사진 추가 권한 안내 문구와 로컬 알림 허용/거부 동작을 실기기에서 확인한다. 코드에는 사진 추가 전용 권한과 알림 요청이 있고 GPS 요청/광고 SDK/ATT는 발견하지 못했다. 권한 거부 UI 실제 실행은 **미검증**이다.
7. 변경 사항을 검토해 출시 브랜치에 반영하고 App Store 배포 서명/export, 버전·빌드 번호 중복 여부, 암호화 신고, 스크린샷·지원 URL·심사 계정을 확인한다. 개발 서명 archive는 App Store 제출 완료가 아니다.
8. 공개 피드 0건 상태의 출시 의도를 결정하고, 필요하면 운영자가 공식 콘텐츠를 준비한다. 사용자 글 작성·탐색/팔로우는 현재 노출 범위 밖이다. 심사 메모에는 `My Page → 설정 → 계정 삭제`, 댓글/글의 `신고 → 사용자 차단`, 설정의 차단 관리 위치, 로그인용 심사 계정과 기능 범위를 적는다. 신고의 24시간 검토를 약속하는 문구에 맞는 운영 대응도 준비한다.
