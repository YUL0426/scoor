# P0 Release Blockers — Resolution Status

Branch: `fix/p0-release-blockers` (one commit per issue). Baseline: `main`.

| # | Issue | Status | Commit scope |
|---|-------|--------|--------------|
| P0-1 | 소셜 레이어 가짜 데이터가 실데이터처럼 표시 | ✅ 정직화 (완전 해결은 백엔드 필요) | Feed/World/Discover에 "미리보기 — 예시 콘텐츠" 배너, 홈 라이브 티커를 본인 데이터 기반 "Your rhythm" 티커로 교체, 허위 문구 6종 제거 |
| P0-2 | 이메일 가입이 가짜 | ✅ | Keychain + salt + PBKDF2(120k) 로컬 자격증명, 비밀번호 검증/중복 처리 실동작 |
| P0-3 | Google 로그인 100% 실패 (GIDClientID 부재) | ✅ 주입 경로 구축 | Config/Info.plist(INFOPLIST_FILE 병합) + Secrets.xcconfig, 미설정 시 버튼 숨김. **실제 client id 발급은 운영 작업** |
| P0-4 | 계정 삭제 부재 (5.1.1(v)) | ✅ | 설정 → 계정 삭제: 전체 로컬 데이터 + 자격증명 + 세션 삭제 |
| P0-5 | 설정 죽은 메뉴 4개 | ✅ | Theme 피커(앱 전역 적용), Language(iOS 설정), Privacy/Terms 링크 + 랜딩에 /privacy·/terms 페이지 신설 |
| P0-6 | 게스트북 재시작 시 유실 | ✅ | GuestbookRecord(SwiftData) + SwiftDataGuestbookService, 프로덕션 배선 |
| P0-7 | 이메일 사용자 기록 고아화 | ✅ | 이메일 정규화 기반 결정적 UUID — 재로그인 시 기록 복원 |
| P0-8 | 어드민 하드코딩 자격증명/클라이언트 인증 | ✅ | env 자격증명(SHA-256) + HMAC 서명 httpOnly 쿠키 + proxy.ts 서버측 라우트 보호. 번들에서 비밀 제거 확인 |
| P0-9 | git 저장소 부재 | ✅ | `git init` + 베이스라인 커밋 + 이슈별 커밋 |
| P0-10 | 딥링크/AASA 플레이스홀더 | ✅ | AASA = `G83W9HD6G7.com.euro.Scoor`, 스토어 미출시 동안 배지 "Coming soon" 처리, 가짜 JSON-LD 평점 제거, assetlinks(안드로이드 앱 없음) 제거 |

## 배포 전 운영 체크리스트 (코드 외 작업)

1. **Google OAuth**: Google Cloud Console에서 iOS client id 발급 →
   `Config/Secrets.xcconfig`에 `GID_CLIENT_ID` 설정 (예시 파일 참고).
2. **어드민**: 배포 환경에 `ADMIN_EMAIL`, `ADMIN_PASSWORD_SHA256`,
   `ADMIN_SESSION_SECRET` 설정 (`admin/.env.example`).
3. **App Store**: 앱 등록 후 `landing/lib/site.ts`의 `appStoreId` 입력,
   `STORE_STATUS.appStoreLive = true`.
4. **Universal Links**: Xcode에서 Associated Domains(`applinks:scoor.app`)
   capability 추가 후 AASA 검증.
5. **백엔드**: 소셜 레이어 실데이터화(P0-1의 궁극적 해결), Apple/Google 토큰
   서버측 revocation(계정 삭제 보완)은 백엔드 도입 시 과제.
