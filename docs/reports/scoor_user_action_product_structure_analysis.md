# Scoor User Action & Product Structure Analysis

분석 기준: `/Users/a0/Desktop/Scoor/Scoor.xcodeproj`의 현재 Swift 코드 구현. 본 문서는 미래 기획안이 아니라, 현재 구현된 화면, 상태, 목 데이터, placeholder를 기준으로 한 역공학 제품 분석이다.

## 1. Executive Summary

Scoor는 현재 "하루의 감정/컨디션을 0-100점으로 기록하고, 그 점수를 개인 회고와 전세계 감정 흐름에 연결하는" SwiftUI iOS 앱으로 구현되어 있다. 핵심 제품 정체성은 일기 앱보다 가볍고, SNS보다 감정 점수 중심인 "emotional score network"에 가깝다.

주요 구현 근거는 `Score`, `ScoreEntry`, `ScoreInputViewModel`, `HomeViewModel`, `StatsViewModel`, `FeedModels`, `WorldTopicModels`에 있다. 개인 기록은 `MockScoreService` 메모리 저장소에 저장되고, 피드/월드/토픽 데이터는 대부분 정적 Mock 데이터다. SwiftData `ScoreModel`과 `modelContainer`는 존재하지만 실제 서비스 계층에서 사용되지 않는다.

현재 코어 루프는 3개다. 첫째, 매일 점수와 이유를 기록한다. 둘째, Home/My Page/Stats에서 내 감정 패턴과 streak를 확인한다. 셋째, Feed/World에서 타인의 감정 또는 글로벌 토픽 감정과 비교하고 반응한다. 다만 소셜 루프는 대부분 로컬 상태/목 데이터 수준이며, 댓글/리포스트/공유/친구 기능은 UI 슬롯만 존재한다.

---

# 2. Global App Structure

## Main Navigation

현재 앱 진입은 `ScoorApp.swift`의 `RootFlowView`와 `AppFlowCoordinator` 상태 머신이 담당한다.

- Splash: `SplashView`
- Signup Welcome: Apple/Google/Email 진입, `SignupWelcomeView`
- Email Login: 이메일/비밀번호 mock 검증, `SignupLoginOptionsView`
- Nickname: 닉네임 mock availability, 숫자형 아바타 선택, `SignupNicknameView`
- Signup Complete: 자동 진행 가능한 환영 화면, `SignupCompleteView`
- Tour: 2페이지 제품 설명, `OnboardingView`
- First Scoor: 최초 점수 입력, `FirstScoorPromptView`
- First Scoor Success: 제출 후 월드 편입 메시지, `FirstScoorSuccessView`
- Main: `ContentView`

메인 앱은 `ContentView.swift` 기준 4탭 구조다.

- Home
- Feed
- World
- My Page

중앙 FAB는 모든 탭 위에 떠 있으며 `ScoreHomeView`를 `.sheet`로 연다. Stats는 독립 탭에서 제거되어 My Page 안의 `StatsSummarySection`과 `NavigationLink -> StatsView`로 흡수되어 있다.

Modal/Sheet 구조:

- `ContentView`: 중앙 FAB -> `ScoreHomeView`
- `ScoreHomeView`: 점수 원형 탭 -> `NumericKeypadSheet`, 이유 필드 탭 -> `ReasonInputSheet`
- `MyPageView`: 설정 -> `SettingsView`, 캘린더 날짜 -> 상세/입력 sheet
- `StatsView`: 월간 공유 -> `InstagramStoryShareSheet`
- `WorldView`: 토픽 선택 -> `TopicDetailView`
- `TopicDetailView`: "What's your Scoor?" -> `TopicScoreSheet`
- `ExploreMapView`: 국가 선택 sheet는 코드상 있으나 실제 선택 트리거가 없다.

## Current Core Modules

### Home

목적: 개인 감정 상태의 첫 화면. 오늘 점수, 주간 흐름, AI-style insight, 라이브 피드, 최근 기록, streak를 보여준다.

구현 상태: 상당히 구현됨. 데이터는 `ScoreServiceProtocol` 기반의 개인 기록과 `HomeViewModel.seedLiveFeed` mock이 섞여 있다.

주요 화면/컴포넌트: `HomeView`, `TodayHeroCard`, `AIInsightSection`, `LiveFeelingTicker`, `RecentEmotionList`, `StreakLifeFlowStrip`.

주요 액션: Record today, 히어로 슬라이드 스와이프, 최근 기록 카드 탭 슬롯(현재 기본 no-op), 알림 아이콘 노출(동작 없음).

연결 모델/서비스: `Score`, `ScoreEntry`, `HomeViewModel`, `ScoreServiceProtocol`, `UserServiceProtocol`.

### Daily Scoor Input

목적: 하루 점수와 이유 저장.

구현 상태: 구현됨. 단, 저장소는 `MockScoreService` 메모리 배열이며 앱 재시작 후 점수 지속성은 없다.

주요 화면: `ScoreHomeView`, `NumericKeypadSheet`, `ReasonInputSheet`, 최초 진입용 `FirstScoorPromptView`.

주요 액션: 점수 입력/수정, 이유 입력, Quick Tag 추가, 기존 날짜 기록 수정, 제출 후 피드백 표시 및 자동 dismiss.

연결 모델/서비스: `ScoreInputViewModel`, `FeedbackEngine`, `MockScoreService`, `NotificationCenter.scoorScoreStoreDidChange`.

### Feed

목적: 사람들의 하루 감정 점수/한 줄을 보는 커뮤니티 피드.

구현 상태: 부분 구현. 피드 데이터는 `MockFeed.entries`; 좋아요/공감은 로컬 상태로 동작한다. 댓글/리포스트는 버튼 슬롯만 있고 실동작 없음.

주요 화면: `FeedView`, `FeedCardView`, `MoodFilterView`, `LivePulseView`, `ReactionBarView`.

주요 액션: 정렬 탭 선택, 감정 필터 선택, pull-to-refresh, 좋아요 토글, 공감 picker 선택.

연결 모델/서비스: `FeedEntry`, `Mood`, `PostReactions`, `EmpathyReaction`, `MockFeed`.

### World

목적: 전세계 토픽에 대해 감정 점수를 매기고 비교하는 실시간 토픽 피드.

구현 상태: UI/인터랙션은 많이 구현됨. 데이터와 제출 결과는 `MockWorld` 및 `TopicDetailView` 내부 상태에 머문다.

주요 화면: `WorldView`, `WorldTrendingRow`, `WorldPostCardView`, `TopicDetailView`, `TopicScoreSheet`.

주요 액션: 카테고리 필터, 정렬 탭, 토픽 선택, 토픽 상세 보기, 국가별 반응 비교, 스포츠 토픽에서 match/team/MVP 점수 매기기, 토픽 점수 제출.

연결 모델/서비스: `WorldTopic`, `WorldPost`, `TopicDetail`, `RegionalReaction`, `SportsMetadata`, `ScoorTarget`, `MockWorld`.

### My Page / Profile

목적: 내 프로필, 월간 평균, 캘린더 기록, 방명록, 통계 진입.

구현 상태: 핵심 구조 구현. 방명록은 mock service, 자기 자신에게 쓰는 구조다. Reply/Delete 버튼은 placeholder다.

주요 화면: `MyPageView`, `ProfileHeaderView`, `CalendarSectionView`, `CalendarDayDetailSheet`, `GuestbookSectionView`, `StatsSummarySection`.

주요 액션: 이전/다음 달 이동, 날짜 선택, 과거 날짜 점수 추가/수정, 방명록 작성, Stats 상세 진입, Settings 열기.

연결 모델/서비스: `MyPageViewModel`, `ScoreEntry`, `GuestbookMessage`, `GuestbookServiceProtocol`, `UserServiceProtocol`.

### Stats / Recap

목적: Daily/Weekly/Monthly 단위의 감정 통계, 패턴 요약, 공유용 리포트 카드.

구현 상태: 구현됨. "Recap"이라는 별도 네이밍 모듈은 없지만 월간 공유 리포트와 패턴 요약이 Recap 역할을 한다. 공유 버튼의 실제 Instagram/갤러리 연동은 미구현이다.

주요 화면: `StatsView`, `StatsViewModel`, `WeeklyBarChartView`, `InstagramStoryShareSheet`.

주요 액션: 기간 탭 전환, 월간 공유 sheet 열기, Not now로 닫기.

연결 모델/서비스: `StatsPeriod`, `WeeklyBarColumn`, `MonthlyHeatCell`, `PatternSummaryRow`, `ScoreEntry`.

### Onboarding / Auth

목적: 빠른 가입, 닉네임 소유감, 첫 점수 기록까지의 activation.

구현 상태: 플로우 구현. 인증은 모두 mock이며 실제 OAuth/계정 생성 없음. 플로우 진행 단계와 일부 사용자 정보는 `UserDefaults`에 저장된다.

주요 액션: Apple/Google/Email 선택, 이메일 mock 가입, 닉네임 검증, 아바타 숫자 변경, 온보딩 스킵/다음, 첫 점수 저장/스킵.

연결 모델/서비스: `AppFlowCoordinator`, `MockUserService`, `MockUsernameAPI`, `UserDefaults`.

### Explore / Social / Settings

목적: 과거 또는 대체 구조의 지도/소셜/설정 화면으로 보인다.

구현 상태: 대부분 placeholder 또는 현재 탭 구조에서 미연결.

근거:

- `ExploreMapView`, `CountryFeedView`, `WorldViewModel`은 지도 기반 글로벌/로컬 구조를 갖지만 `ContentView` 탭에 연결되지 않는다.
- `SocialView`는 v2 placeholder이며 현재 탭에 없다.
- `SettingsView`는 List 항목만 있고 상세 액션이 없다.

---

# 3. User Action Taxonomy

| Category | Action Name | Trigger Point | User Intent | Related View/ViewModel | Status | Notes |
|---|---|---|---|---|---|---|
| Account | Apple로 시작 | Signup Welcome button | 빠른 가입 | `SignupWelcomeView`, `AppFlowCoordinator` | Partial | 실제 OAuth 없음, provider만 저장 |
| Account | Google로 시작 | Signup Welcome/Login button | 빠른 가입 | `SignupWelcomeView`, `SignupLoginOptionsView` | Partial | mock delay 후 진행 |
| Account | Email 가입 | Email form Continue | 이메일 계정 생성 | `SignupLoginOptionsView` | Partial | 형식/길이 검증, `taken@scoor.app`만 에러 |
| Account | 닉네임 입력 | Nickname field | 공개 ID 설정 | `SignupNicknameView` | Partial | mock availability |
| Account | 아바타 변경 | Avatar circle tap | 프로필 표현 선택 | `SignupNicknameView` | Implemented | 숫자형 avatar 문자열 저장 |
| Account | 설정 열기 | My Page gear | 계정/환경 관리 | `MyPageView`, `SettingsView` | Placeholder | 상세 설정 없음 |
| Onboarding | Splash 완료 | 1.6초 timer | 앱 진입 | `SplashView`, `AppFlowCoordinator` | Implemented | 매 실행 splash 후 저장 stage로 이동 |
| Onboarding | Tour 다음/스킵 | Next/Skip | 제품 이해 | `OnboardingView` | Implemented | 2페이지 |
| Onboarding | 첫 Scoor 저장 | Save my first Scoor | activation | `FirstScoorPromptView`, `RootFlowView` | Implemented | mock score service 저장 |
| Onboarding | 첫 Scoor 스킵 | Skip | 빠른 메인 진입 | `FirstScoorPromptView` | Implemented | 저장 없이 main |
| Daily Input | 오늘 점수 열기 | 중앙 FAB, Home Record today | 오늘 기록 | `ContentView`, `HomeView`, `ScoreHomeView` | Implemented | sheet |
| Daily Input | 점수 숫자 편집 | Score ring tap | 숫자 직접 입력 | `ScoreHomeView`, `NumericKeypadSheet` | Implemented | 0-100 제한 |
| Daily Input | 이유 입력 | Why this score? | 맥락 기록 | `ReasonInputSheet` | Implemented | 200자 제한은 VM에서 적용 |
| Daily Input | Quick Tag 추가 | Work/Family/Health/Hobbies | 빠른 이유 태깅 | `ReasonInputSheet` | Implemented | 영문 태그만, 별도 구조화 아님 |
| Daily Input | 점수 제출/수정 | Score/Update Score | 저장 | `ScoreInputViewModel` | Implemented | 같은 날짜 기존 점수 제거 후 저장 |
| Daily Input | 과거 날짜 기록 | My Page calendar empty date | backfill | `MyPageView`, `ScoreHomeView(targetDate:)` | Implemented | 미래 날짜 비활성 |
| Daily Input | 날짜 기록 상세 보기 | Calendar scored date tap | 회고 | `CalendarDayDetailSheet` | Implemented | edit 가능 |
| Home | Hero slide swipe | `TodayHeroCard` TabView | 오늘/주간/흐름 탐색 | `HomeSections` | Implemented | 3 slides |
| Home | Live ticker 자동 전환 | Timer task | 월드 감정 체감 | `LiveFeelingTicker` | Implemented | mock |
| Home | 최근 기록 탭 | Recent row | 과거 회고 | `RecentEmotionList` | Placeholder | 기본 클로저 no-op |
| Home | 알림 확인 | Bell icon | 알림 보기 | `HomeView` | Placeholder | 버튼도 아니고 동작 없음 |
| Feed | 정렬 선택 | 실시간/인기/비슷한 기분 | 피드 큐레이션 | `FeedView` | Partial | 상태만 바뀌고 정렬 로직 없음 |
| Feed | 감정 필터 | Mood chip | 관심 감정 보기 | `MoodFilterView` | Implemented | primary/extraTags 필터 |
| Feed | 새로고침 | pull-to-refresh | 최신 피드 보기 | `FeedView.refresh()` | Partial | mock swap |
| Feed | 좋아요 | heart | 공감/반응 | `ReactionBarView` | Implemented-local | 로컬 count만 변경 |
| Feed | 댓글 | bubble icon | 대화 | `ReactionBarView` | Placeholder | 기본 no-op |
| Feed | 리포스트 | repost icon | 확산 | `ReactionBarView` | Placeholder | 기본 no-op |
| Feed | 공감 선택 | hands.sparkles | 감정적 지지 | `ReactionBarView` | Implemented-local | 4개 glyph picker |
| World | 정렬 선택 | 실시간/뜨거움/급상승 | 토픽 큐레이션 | `WorldView` | Partial | 상태만 바뀌고 정렬 적용 약함 |
| World | 카테고리 선택 | WorldCategory chip | 채널 탐색 | `WorldCategoryFilter` | Implemented | posts/topics 필터 |
| World | 토픽 상세 열기 | trending card/topic row | 맥락 확인 | `WorldView`, `TopicDetailView` | Implemented | sheet |
| World | 지역 비교 선택 | Region chip | 국가별 감정 비교 | `TopicDetailView` | Implemented | row highlight |
| World | 토픽 점수 제출 | Bottom CTA | 내 반응 기록 | `TopicScoreSheet`, `TopicDetailView` | Partial | 상세 화면 내부 상태만 반영 |
| World | 스포츠 팀/MVP 점수 | Sports panel cells | 세부 대상 평가 | `TopicDetailView`, `ScoorTarget` | Partial | 상태만 저장 |
| Stats | 기간 전환 | Daily/Weekly/Monthly picker | 분석 범위 전환 | `StatsViewModel` | Implemented | reload |
| Stats | 월간 리포트 공유 열기 | Share Report Card | 외부 공유 | `StatsView` | Partial | sheet만 구현 |
| Stats | Instagram 공유 | Share to Instagram Story | 공유 | `InstagramStoryShareSheet` | Placeholder | 버튼 no-op |
| Stats | 갤러리 저장 | Save to Gallery | 저장 | `InstagramStoryShareSheet` | Placeholder | 버튼 no-op |
| Profile | 월 이동 | Calendar chevron | 과거 기록 탐색 | `CalendarSectionView` | Implemented | 월 평균 갱신 |
| Profile | 방명록 작성 | TextField + paperplane | 프로필 메시지 | `GuestbookSectionView` | Partial | 자기 자신 author/recipient, mock 메모리 |
| Profile | Reply/Delete | Guestbook row buttons | 답장/관리 | `GuestbookMessageRow` | Placeholder | no-op |
| Explore | 지도 검색 | Search field | 국가/도시 찾기 | `ExploreMapView` | Placeholder | 연결 없음 |
| Social | 친구 소셜 보기 | Social tab assumed | 친구 점수 보기 | `SocialView` | Placeholder/Missing | 탭에 미연결 |
| Premium | 프리미엄 구매 | 없음 | 수익화 | 없음 | Missing | 코드상 premium 기능 없음 |
| Notifications | 알림 설정/확인 | Bell/Settings label | 리텐션 알림 | `HomeView`, `SettingsView` | Placeholder | 권한/스케줄 없음 |

---

# 4. Core Product Loops

## Daily Logging Loop

Entry: 온보딩 첫 점수, Home Record today, 중앙 FAB, My Page 캘린더 빈 날짜.

Trigger: "How was your day?", 날짜 표시, streak/month avg, 빈 상태 메시지.

Reward: 저장 후 `FeedbackEngine` 메시지, Home 히어로 숫자 변화, Stats/Calendar 즉시 반영.

Retention: streak, 월간 평균, 최근 기록, 주간/월간 패턴. 현재 리텐션은 로컬 분석 중심이며 push notification은 없다.

## Personal Reflection / Stats Loop

Entry: My Page -> Stats 더 보기, Home insight, 캘린더 날짜 상세.

Trigger: 최고/최저 요일, 주간 평균 대비, 월간 heatmap, "AI INSIGHT".

Reward: 내가 어떤 요일/기간에 높고 낮은지 확인.

Retention: 패턴 발견, 월간 리포트 공유 욕구. 다만 AI는 실제 모델 호출이 아니라 rule-based copy다.

## Social Comparison Loop

Entry: Feed tab, World tab, Home live ticker.

Trigger: live count, 평균 점수, 도시/토픽별 점수, 타인의 한 줄 감정.

Reward: 내 감정이 혼자가 아니라는 감각, 좋아요/공감 로컬 피드백.

Retention: 실시간성 연출. 현재 backend stream이 없어서 제품 루프는 mock 수준이다.

## Topic Reaction Loop

Entry: World trending topic -> detail -> score sheet.

Trigger: 글로벌 점수, delta, 국가별 비교, 스포츠 match/team/MVP 패널.

Reward: "내 Scoor" 배지, overlay feedback, 토픽 globalScore 소폭 보정.

Retention: 사회/스포츠/주식/코인 등 이벤트 기반 재방문. 현재 저장/공유/피드 반영은 없음.

## Activation Loop

Entry: Signup -> Nickname -> Tour -> First Scoor.

Trigger: "Start in seconds", "Trust the first feeling".

Reward: 첫 점수가 세계의 일부가 되었다는 success 화면.

Retention: 이후 Main 진입. 단, 실제 계정/원격 저장이 없으므로 activation의 장기 효과는 제한적이다.

---

# 5. Current UX Patterns

강점:

- 점수 입력 UX가 매우 명확하다. 큰 숫자, 원형/슬라이더/키패드, 햅틱, 저장 후 피드백이 일관된 "score-first" 정체성을 만든다.
- Home은 감정적 UX가 가장 강하다. 점수 자체보다 "today mood phrase", "emotional flow", "recent days"로 의미를 만든다.
- Feed/World는 Threads/Toss 커뮤니티 톤의 flat stream, hairline divider, 작은 점수 배지를 사용해 읽기 밀도를 높인다.
- World 상세는 토픽 감정 평가라는 차별화된 제품 방향이 선명하다. 특히 스포츠 match/team/MVP target은 확장성이 있다.

불일치:

- Home/Score/Stats/My Page는 밝은 카드 기반이고, Feed/World는 다크 flat stream이다. 제품적으로는 "개인=따뜻한 회고, 사회=라이브 다크 피드"로 해석 가능하지만 전환감은 크다.
- Score 입력은 `FirstScoorPromptView`, `ScoreHomeView`, `TopicScoreSheet` 세 갈래로 존재한다. 모두 점수 입력이지만 조작 방식과 저장 의미가 다르다.
- Stats에 Daily/Weekly/Monthly가 모두 있으나 `StatsPeriod` 주석은 "only Weekly + Monthly"라고 되어 있어 구현/주석 불일치가 있다.
- Home의 "AI INSIGHTS"와 Stats의 "AI INSIGHT"는 실제 AI가 아니라 rule-based 계산이다. 카피가 제품 기대치를 과하게 만들 수 있다.

미완성 UX:

- Feed/World의 sort tab은 대부분 시각 상태만 바꾼다. 사용자는 정렬 결과가 바뀔 것으로 기대하지만 실제 데이터 정렬은 거의 없다.
- 댓글/리포스트/공유/방명록 Reply/Delete는 동작이 없어 신뢰를 떨어뜨릴 수 있다.
- Settings는 리스트만 있고 상세 화면/토글이 없다.
- Explore/Social은 파일은 있으나 현재 메인 내비게이션에 연결되지 않는다.

중복 패턴:

- streak 계산이 `HomeViewModel`, `StatsViewModel`, `MyPageView`에서 각각 구현되어 있다.
- calendar day indexing은 `ScoreCalendarIndex`가 있으나 Home/Stats에서 자체 dictionary 변환을 반복한다.
- 피드 액션 UI는 `ReactionBarView`로 잘 재사용되지만, 실제 액션 이벤트 계층은 없다.

---

# 6. Data & State Structure

## Persistence

현재 지속 저장은 사실상 `UserDefaults` 중심이다.

- `AppFlowCoordinator`: `scoor.appFlow`, `scoor.chosenUsername`, `scoor.chosenAvatarEmoji`, `scoor.authProvider`, `scoor.authEmail`, legacy `hasCompletedOnboarding`.
- `MockUserService`: username/avatar를 같은 UserDefaults 키로 읽고 쓴다.

점수 데이터는 `MockScoreService.storage` 메모리 배열에 저장된다. `saveScore`는 동일 user/date의 기존 점수를 제거하고 새 점수를 넣는다. 앱 재시작 지속성은 없다.

SwiftData:

- `ScoreModel`과 `ScoorApp.modelContainer(for: [ScoreModel.self])`는 존재한다.
- 그러나 `@Query`, `modelContext`, SwiftData 기반 repository가 없어서 실제 점수 저장에는 사용되지 않는다.

## State Management

- 앱 플로우: `@StateObject AppFlowCoordinator` + `@EnvironmentObject`.
- 서비스 주입: `AppServices`가 mock protocol들을 보관하고 environment로 전달.
- 화면 상태: 대부분 `@State`, 화면별 `@StateObject ViewModel`.
- 변경 브로드캐스트: 점수 저장 시 `NotificationCenter.default.post(.scoorScoreStoreDidChange)`로 Home/MyPage/Stats reload.

## Domain Model Structure

개인 기록 도메인:

- `Score`: value, reason, date, locationId.
- `ScoreEntry`: 캘린더/통계 UI용 일 단위 projection.
- `ScoreCalendarIndex`: 일 단위 dictionary 변환.

소셜 피드 도메인:

- `FeedEntry`, `LightIdentity`, `Mood`, `Weather`, `PostReactions`, `EmpathyReaction`.

월드 토픽 도메인:

- `WorldTopic`, `WorldPost`, `WorldPulse`, `TopicDetail`, `RegionalReaction`, `SportsMetadata`, `ScoorTarget`.

프로필/방명록:

- `User`, `GuestbookMessage`, `GuestbookMessageDisplay`.

미래 backend 가정:

- Protocol 기반 `ScoreServiceProtocol`, `UserServiceProtocol`, `GuestbookServiceProtocol`은 backend 교체를 염두에 둔 구조다.
- `Location`, `ScoreAggregate`, `WorldMapBubble`, `CountryFeedUserEntry`는 글로벌 지도/집계 시스템 의도를 보여준다.
- 현재는 인증, feed, world, guestbook, stats 모두 local/mock이므로 서버 이벤트 모델은 아직 없다.

---

# 7. Product Architecture Assessment

Scoor가 되어가는 제품은 단순 mood tracker가 아니라 "감정 점수를 개인 회고와 집단 감정 지표로 연결하는 플랫폼"이다. 가장 강한 제품 정체성은 "one number emotional check-in + global pulse"다.

강한 축:

- Daily score input: 제품의 가장 명확한 core identity.
- Home emotional dashboard: 점수를 감정 언어로 번역하는 UX.
- World topic scoring: 범용 SNS와 다른 차별화 지점.

겹치는 축:

- Feed와 World 모두 "타인의 감정 글 스트림"이다. Feed는 개인 하루 감정, World는 토픽 반응으로 구분되지만 액션 바/스트림 구조가 거의 같다.
- ExploreMapView/WorldViewModel의 지도 기반 World와 현재 `WorldView`의 토픽 기반 World가 서로 다른 제품 방향이다. 현재 탭은 토픽 기반 World를 채택했다.
- SocialView는 친구 기반 관계망을 암시하지만 Feed/Guestbook과 역할이 겹친다.

죽은 기능 또는 미연결 기능:

- `ScoreInputView`: 현재 탭/플로우에 연결되지 않는 구형 Score tab shell로 보인다.
- `ExploreMapView`, `CountryFeedView`, `WorldViewModel`: 현재 메인 탭에 없음.
- `SocialView`: placeholder이며 미연결.
- `ScoreModel`: SwiftData model이나 서비스에서 미사용.

명확하지 않은 내비게이션:

- My Page는 NavigationStack 안에 있지만 `navigationBarHidden(true)`와 toolbar를 같이 사용한다. 설정 버튼 노출 일관성이 애매할 수 있다.
- Stats는 탭에서 제거되어 My Page 깊숙이 들어갔지만, Home에서도 핵심 수치를 보여주기 때문에 사용자가 "분석은 어디서 보는가"를 학습해야 한다.

확장성 리스크:

- Mock static 데이터가 View와 Model에 강하게 붙어 있어 API 전환 시 Feed/World/ViewModel 분리가 필요하다.
- `NotificationCenter` 기반 reload는 초기에는 간단하지만 이벤트가 늘면 원인 추적이 어렵다.
- scoring, calendar indexing, streak, insight 계산이 여러 곳에 분산되어 도메인 서비스로 수렴할 필요가 있다.

---

# 8. Suggested Action Priority

## P0: Core identity

- 오늘 점수 기록/수정: `ScoreHomeView`, `ScoreInputViewModel`
- 첫 점수 activation: `FirstScoorPromptView`
- 점수 저장 지속성 실제화: 현재 `MockScoreService` -> SwiftData 또는 backend
- Home 히어로와 오늘 상태 반영: `HomeViewModel`
- My Page 캘린더 기록/수정: `CalendarSectionView`, `CalendarDayDetailSheet`

## P1: Retention drivers

- Streak 계산 단일화
- Weekly/Monthly stats 신뢰도 개선
- 월간 recap/share 실제 동작 구현
- 알림/리마인더 권한 및 설정 구현
- Home recent entry 탭을 상세/수정으로 연결

## P2: Social expansion

- Feed 댓글/리포스트 실제 flow
- Feed sort 로직 구현
- World 토픽 점수 저장 및 피드 반영
- Guestbook Reply/Delete 구현
- 친구 기반 Social을 유지할지, Feed/Guestbook으로 흡수할지 결정

## P3: Delight/polish

- 애니메이션/햅틱 세부 polish
- dark/light 전환의 의도 명확화
- Settings 상세 화면
- TopicScoreSheet comment 저장/노출
- 공유 카드 실제 이미지 렌더/저장

---

# 9. Missing but Implied Features

## Implemented Reality

- 앱 플로우 상태 머신과 UserDefaults 기반 재개.
- mock 인증 및 닉네임 생성.
- 개인 점수 입력/수정, reason 저장.
- Home/Stats/MyPage에서 개인 점수 기반 분석.
- Feed mock stream과 좋아요/공감 로컬 반응.
- World mock topic stream, 상세, 지역 비교, 스포츠 target scoring.
- Guestbook mock 작성.

## Inferred Future Direction

코드가 암시하지만 현재 실구현이 아닌 것:

- 실제 계정/Auth: `AuthProvider`, auth email/provider 저장은 있으나 실제 인증 없음.
- 실제 로컬 persistence: `ScoreModel`이 있으나 서비스 미연결.
- backend score/feed/world service: protocol 구조와 mock service 네이밍이 교체 가능성을 암시.
- 글로벌 지도/지역 피드: `ExploreMapView`, `WorldViewModel`, `ScoreAggregate`, `Location`이 존재하지만 현 탭에서 배제.
- 친구 소셜: `SocialView` placeholder.
- Notification/reminder: Home bell, Settings Notifications label만 존재.
- Premium/monetization: 코드상 직접 구조 없음. 수익화는 현재 구현 근거가 없다.
- Recap 공유: `InstagramStoryShareSheet` UI는 있으나 실제 share/save action 없음.

제품적으로 다음 결정을 가장 먼저 해야 한다. Scoor의 사회적 표면을 "개인의 하루 감정 Feed"로 갈지, "세상 토픽에 점수를 매기는 World"로 갈지, 혹은 두 축을 명확히 분업할지 정해야 한다. 현재 코드의 가장 독창적인 방향은 World topic scoring이고, 가장 완성도 높은 habit loop는 daily score logging이다. 따라서 P0는 daily scoring의 지속 저장과 분석 신뢰도, P1은 World scoring의 실제 이벤트화로 보는 것이 타당하다.
