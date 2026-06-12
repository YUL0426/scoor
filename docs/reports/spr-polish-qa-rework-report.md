# Scoor Sprint 2 — QA 리워크 라운드 보고

작성일: 2026-06-11 · 브랜치: `sprint2-foundations`

세 가지 QA 지적사항을 수정·재검증했습니다.

---

## 1. 원래 무엇을 오해했는가

1. **My Scoors 위치**: "프로필을 탭하면 My Scoors"를 **My Page 탭**으로 오해 → 실제는 **Home 화면 우상단 프로필/아바타 아이콘**.
2. **현지화 범위**: 화면 정적 라벨만 현지화하고, Home의 **동적 카피(무드 문구·AI 인사이트·감정 흐름·날짜 포맷·서브메시지·라이브 티커)** 와 컴퓨티드 String 라벨(Streak/Month Avg/Happiest)을 누락 → Home에 영어 잔존.
3. **World 점수 가시성**: Feed만 점수 우선으로 강화하고 World 카드는 작은 18pt 배지 그대로 둠.

## 2. 무엇을 수정했는가

### QA#1 — Home 프로필 → My Scoors
- Home 우상단 프로필 아이콘 탭 → **My Scoors 시트**(내가 점수 매긴 토픽: 제목·내 점수·내 사유·날짜, 검색 지원) 오픈. (`home-profile-button`)
- 데이터: `appServices.socialService.myWorldScores()` 로드, 소셜 저장소 변경 시 갱신.
- **My Page는 원래 동작(이번 달 대표 감정)으로 복원** — "My Page 미수정" 원칙 준수.
- MyScoorsView 빈 상태 개선(검색 결과 없음 vs 아직 점수 없음 구분).

### QA#2 — Home 전체 현지화
- 동적 카피 현지화: `MoodCopy` 문구(9), 서브메시지(5), `EmotionalFlow.displayText`(4), AI 인사이트(보간 포함 7), 라이브 티커(6), "No note for this day".
- 날짜 포맷: `en_US_POSIX` 고정 제거 → `setLocalizedDateFormatFromTemplate` + `.current` 로캘(요일/월/일 순서 자동).
- 컴퓨티드 라벨: Streak/Month Avg/Happiest를 `LocalizedStringKey`로, 주간 바 차트 요일 약자를 로캘 `veryShortWeekdaySymbols`로.
- 카탈로그 **232 키 × 7 언어**로 확장.

### QA#3 — World 점수 가시성
- `WorldPostCardView`를 Feed와 동일하게 **점수 우선**: 내 점수를 우측에 크게 고정(40pt heavy, 톤 컬러, 후광, 100→로고).
- 트렌딩 미니카드 점수 26→32pt(100→로고).

## 3. 수정 파일
- `Views/Home/HomeView.swift` (프로필→My Scoors, HomeProfilePanel 제거)
- `ViewModels/HomeViewModel.swift` (동적 카피·날짜 현지화)
- `Views/Home/HomeSections.swift` (라벨·요일·평균 현지화)
- `Views/MyPage/MyPageView.swift`, `ViewModels/MyPageViewModel.swift` (감정 이력 복원)
- `Views/MyPage/MyScoorsView.swift` (빈 상태)
- `ContentView.swift` (My Page 시그니처 복원)
- `Views/World/WorldPostCardView.swift`, `Views/World/WorldTrendingRow.swift` (점수 우선)
- `Scoor/Localizable.xcstrings` (+신규 Home 키)

## 4. 빌드 상태
`xcodebuild clean build` → **BUILD SUCCEEDED** (에러 0).

## 5. 스크린샷 (`docs/reports/spr-polish-screenshots/`)
- `qa-01-home-localized-ko.png` — Home 전체 한국어(날짜 "6월 11일 목요일", "오늘 하루는 어땠나요?", "AI 인사이트", "실시간", "전 세계에서").
- `qa-02-myscoors-from-home.png` — Home 프로필 아이콘 → "나의 Scoor" 시트(검색 포함).
- `qa-03-world-score-first.png` — World 카드 우측 대형 점수(92/18/89) + Feed와 동일 디자인.

## 6. 검증
- UI Test: ScoorSprint2AUITests(2/2) PASS, ScoorQAReworkUITests PASS.
- 현지화: ko 시뮬레이터에서 Home/World 일관 한국어 렌더 확인.

## 7. 남은 런치 블로커
- **기능 블로커 없음.**
- 비블로커 현지화 잔여(투명): MoodAnalyzing 키워드(매칭 토큰·의도적 제외), SocialSeed 목업/미리보기 데이터, 일부 인증/개발자 에러 문자열, FeedbackEngine 동적 마이크로카피. (Home 표면은 해소됨)
- ⚠️ ClickUp 커넥터 일시 장애(net::ERR_FAILED)로 태스크 코멘트/상태 이동 보류 — 복구 후 재시도 필요.
