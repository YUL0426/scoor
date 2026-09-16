# iPhone 전용 배포 준비 — 2026-09-16

## 빌드

- 앱·단위 테스트·UI 테스트의 Debug/Release 설정을 `TARGETED_DEVICE_FAMILY = 1`로 변경했다. iPad 전용 화면 회전 설정도 제거했다.
- 버전 `1.0`, 빌드 `3`, 번들 `com.euro.Scoor`.
- 서명된 Release 아카이브: [Scoor-2026-09-16-iPhone.xcarchive](/Users/yul/Desktop/scoor-workspace/release/Scoor-2026-09-16-iPhone.xcarchive).
- 최종 앱의 `UIDeviceFamily = [1]`, iOS 17.0 이상, 서버 및 Google 로그인 설정 포함을 확인했다. 코드 서명 검증도 통과했다.
- 업로드 및 심사 제출은 실행하지 않았다. Xcode Organizer에서 이 아카이브를 선택해 Distribute App → App Store Connect로 진행하고 새 빌드를 제출 버전에 연결한다. 이전 iPad 지원 아카이브 대신 이 빌드를 사용한다.
- Apple의 [스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)은 iPad 실행을 지원하는 앱에 iPad 스크린샷을 요구한다. 이번 번들은 iPhone 기기군만 포함한다.

## 앱 목업 정리

- 실제 앱에서 사용하는 SwiftData 소셜 서비스가 합성 사용자·피드·World 게시물·추천·토픽 통계를 생성하지 않도록 변경했다. 실제 공개 콘텐츠와 토픽은 기존 서버 서비스에서 조회한다.
- 서버 토픽 조회 실패 시 가짜 토픽으로 대체하지 않는다. 이전에 받은 실제 토픽은 보존하고 오류를 표시한다.
- 예시 사용자·게시물·반응·통계 데이터셋은 Debug 빌드에만 컴파일한다. 프리뷰 안내와 가짜 접속자 수는 명시적으로 주입한 Debug 목업 서비스에서만 표시한다.
- 실제 이메일이 없을 때 `user@scoor.app`을 지어내지 않는다. 알 수 없는 사용자 ID를 현재 사용자로 대체하던 동작도 제거했다.
- 기존 개인 기록, 로컬 반응 및 로그인 상태를 지우는 자동 초기화 코드는 추가하지 않았다.
- 스크린샷 fixture는 기존처럼 Debug 전용이다. Release 실행 파일에서 대표 목업·스크린샷·테스트 인증 문자열 6종이 없는 것을 확인했다.

## 서버 데이터 확인 범위

운영 Supabase를 읽기 전용으로 확인했다. 실제 로그인 계정과 활동을 목업으로 단정할 수 없어 서버 삭제는 실행하지 않았다.

| 데이터 | 확인 수 | 처리 |
| --- | ---: | --- |
| 토픽 | 6 (공개 5, 초안 1) | 유지 |
| 토픽 채점 대상 | 5 | 유지 |
| 계정 | 3 (Google, Apple, 앱 심사용 각 1) | 유지 |
| 개인 점수 | 2 | 유지 |
| 게시물 | 1 | 유지 |
| 댓글 | 1 | 유지 |
| World 반응 | 0 | 변경 없음 |

서버 기록 전체를 초기화하려는 경우 계정 유지 여부와 활동 삭제 범위를 별도로 확정해야 한다. 앱 심사용 계정도 존재하므로 계정 전체 삭제와 목업 제거를 동일하게 처리하지 않았다.

## 검증

- 전체 단위 테스트 **153개 통과, 실패 0개**.
- 새 회귀 테스트 5개: 서버 미설정 시 가짜 데이터 미노출, 실제 로컬 기록 보존, 서버 실패 시 가짜 토픽 대체 방지 및 기존 토픽 보존, 다른 사용자로의 잘못된 대체 방지, 빈 목업 페이지 처리.
- 초기 실행에서 기존 테스트의 한국어 고정 문구 및 혼합된 날짜 형식 기대값이 현지화 결과와 충돌했다. 날짜 경계·집계 검증은 실제 날짜로 검사하고, 익명 표시 검증은 현지화 문자열을 사용하도록 수정한 후 영어/미국 설정의 전체 테스트가 통과했다.
- `xcodebuild archive`: **ARCHIVE SUCCEEDED**.
- `codesign --verify --deep --strict`: 성공.
- [아카이브 검사 결과](/Users/yul/Desktop/scoor-workspace/release/validation-2026-09-16/archive-verification.json), [최종 테스트 결과](/Users/yul/Desktop/scoor-workspace/release/validation-2026-09-16/unit-tests-final.xcresult), [빌드 로그](/Users/yul/Desktop/scoor-workspace/release/validation-2026-09-16/archive.log).

이번 검증은 빌드 설정과 목업 노출 경로에 대한 결과다. TestFlight 업로드, App Store Connect의 새 빌드 연결 및 심사 제출 상태는 확인하지 않았다.
