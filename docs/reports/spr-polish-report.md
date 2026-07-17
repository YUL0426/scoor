# Scoor 런치 전 폴리시 & 버그픽스 스프린트 — 결과 보고

작성일: 2026-06-11 · 브랜치: `sprint2-foundations`

> 범위: 6개 요구사항 중 **#5 Footer Navigation IA Review는 제품 오너 결정으로 취소**. 나머지 5개 구현·검증 완료.

---

## 1. 아키텍처 영향 요약

| 영역 | 변경 | 비고 |
|---|---|---|
| 점수 입력 | 사유 모달/태그 흐름 제거 → 인라인 TextField | `ReasonInputSheet.swift` 삭제. MVVM/저장 플로우 무변경 |
| 점수 렌더 | 재사용 컴포넌트 `ScoreValueView` 신설(100→로고) | 모든 점수 표기의 단일 진입점. 기존 `FeedScoreDisplay`가 이를 경유 |
| 프로필 | 감정 이력 제거 → "My Scoors" 이력 | `SocialServiceProtocol.myWorldScores()` 추가(스키마 변경 없음, `WorldScoreRecord` 투영) |
| 현지화 | String Catalog 도입 | `Localizable.xcstrings` 196키 × 7언어, `knownRegions` 7개 등록 |
| 테스트 | 스킴 TestAction `language="en"` 고정 | 현지화 도입에 따른 UI 테스트 헤르메틱 보장 |

기존 MVVM/SwiftUI 구조, 서비스 프로토콜(Mock+SwiftData 드롭인) 패턴 모두 보존.

## 2. UX 영향 요약

- **점수 입력**: 사유 = 원탭 인라인 타이핑. 모달·태그·중간화면 제거로 제출 마찰 최소화.
- **피드**: 점수가 우측 대형(40pt)으로 고정되어 스크롤 중 즉시 인지(score-first). 본문이 사유 역할.
- **프로필**: "My Scoors"로 내가 매긴 토픽(제목·점수·사유·날짜) + 검색 제공.
- **브랜딩**: 점수 100은 어디서나 Scoor 로고로 치환(피드·상세·프로필·대형 표시·통계).
- **언어**: 디바이스 언어를 따라 한 화면이 한 언어로 일관 표기(혼용 해소).

## 3. 현지화 커버리지 리포트

- 카탈로그: `Scoor/Localizable.xcstrings` — **196 키 × 7 언어**(ko, en, ja, zh-Hans, de, fr, es).
- 빌드 산출물에 7개 `.lproj`(de/en/es/fr/ja/ko/zh-Hans) 생성 확인.
- 커버: Home/Feed/World/Score/MyPage/Settings/Onboarding/Discover/Stats/Recap의 화면 크롬 리터럴 + 삼항/컴퓨티드/토스트 2차 배치 + 알림 카피·저장 에러.
- **의도적 비현지화**: MoodAnalyzing 키워드(매칭 토큰), SocialSeed 목업, 미리보기 데이터, 브랜드 토큰(Scoor/MVP/버전/URL).
- **잔여(후속 권장)**: 일부 enum 표시값(FeedSort/Mood.label), 캘린더 요일 약자(로캘 캘린더로 대체 권장), 일부 인증/개발자 에러 문자열, FeedbackEngine/MoodCopy 동적 마이크로카피(중첩 보간 — 문법 안전성 위해 별도 처리 권장).

## 4. 빌드 결과

`xcodebuild clean build -scheme Scoor -destination 'generic/platform=iOS Simulator'` → **BUILD SUCCEEDED** (에러 0, 사전 존재 경고만).

## 5. 테스트 결과

| 테스트 | 결과 |
|---|---|
| ScoorSprint2AUITests/test1 (인라인 사유 플로우) | ✅ PASS |
| ScoorSprint2AUITests/test2 (점수+사유 영속/파생 무드 없음) | ✅ PASS |
| ScoorPolishScreenshotsUITests (스크린샷·스모크) | ✅ PASS |

## 6. ClickUp 태스크 (Scoor ▸ Launch 리스트)

| # | 태스크 | 링크 |
|---|---|---|
| 1 | Input Flow Simplification | https://app.clickup.com/t/86exx9emv |
| 2 | User Scoor History ("My Scoors") | https://app.clickup.com/t/86exx9en8 |
| 3 | Full Localization Audit — 7 Languages | https://app.clickup.com/t/86exx9ept |
| 4 | Scoor Logo Score Rendering (100 Rule) | https://app.clickup.com/t/86exx9eqf |
| 6 | Feed Score Visibility Upgrade | https://app.clickup.com/t/86exx9er0 |

상태: 작업 시작 시 In Progress 상당(해당 Launch 리스트엔 별도 "In Progress" 상태가 없어 backlog→**in review**로 운용), 완료분 **In Review** 이동. (Done 미사용)

## 7. 스크린샷

`docs/reports/spr-polish-screenshots/`
- `00-landing-korean-l10n.png` — ko 시뮬레이터 한국어 렌더(현지화 증빙)
- `01-score-input-100-logo.png` — 100 입력 시 숫자 대신 Scoor 로고
- `02-inline-reason.png` — 모달/태그 없는 인라인 사유 입력
- `03-feed-score-first.png` — 우측 대형 점수(24/82/38/91)
- `04-mypage-myscoors.png` — My Scoors 섹션 + 통계 100→로고(연속=1은 숫자 유지)

## 8. 남은 런치 블로커

- **기능 블로커 없음.** 5개 항목 빌드·테스트 통과.
- 후속(비블로커) 현지화 잔여 항목은 §3 참조.
- 참고(기존 이슈, 본 스프린트 무관): Google 로그인은 GIDClientID 프로비저닝 대기.
