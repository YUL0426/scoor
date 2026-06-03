# Sprint 1 — 구현 및 E2E QA 리포트

> 작성일: 2026-06-03 · 빌드: Xcode 26.1.1 · 시뮬레이터: iPhone 17 Pro (iOS 26.1)

## 범위
1. 홈(Home) 최근 점수 카드 → 수정 플로우 연결
2. 캘린더 상세 화면에서 점수 삭제 플로우 추가
3. Bio(소개) 업데이트 영속화
4. 위 기능 전체에 대한 E2E UI 테스트

제약: 기존 아키텍처(MVVM) 유지 · 기존 서비스 사용 · UI 리디자인 없음 · 인증/World/Feed 변경 없음.

## 구현 요약

### 1. 홈 최근 카드 → 수정
- `HomeRecentRow`에 `date` 추가 → 탭한 항목의 해당 날짜를 식별.
- `HomeView`가 사용하지 않던 `RecentEmotionList.onTapEntry`를 연결, `ScoreHomeView(targetDate:)`(이미 수정 모드 지원)를 시트로 표시.

### 2. 캘린더 삭제
- `CalendarDayDetailSheet`에 "삭제하기" 버튼 + 확인 다이얼로그 추가.
- `MyPageViewModel.deleteScore(for:)` 추가 — 기존 `ScoreServiceProtocol.deleteScore`(Mock/SwiftData 모두 구현됨)로 삭제 후 reload.

### 3. Bio 영속화
- `User`에 `bio` 필드 추가.
- `UserServiceProtocol.updateBio` 추가, `MockUserService`에서 `UserDefaults`(기존 username 패턴과 동일)로 저장/시드.
- `ProfileEditView` 저장 버튼이 `updateBio`를 호출하도록 연결, 프로필 헤더에 bio 노출.

## QA 결과

전체 UI 테스트 스위트를 **클린 상태(앱 데이터 삭제 후)** 에서 실행.

| 테스트 | 결과 |
|---|---|
| `ScoorPersistenceUITests` (기존 회귀) | ✅ PASS |
| `ScoorSprint1UITests/test1RecentCardEditFlow` | ✅ PASS |
| `ScoorSprint1UITests/test2CalendarDeleteFlow` | ✅ PASS |
| `ScoorSprint1UITests/test3BioPersistence` | ✅ PASS |

```
Executed 4 tests, with 0 failures (0 unexpected) in 166.6 seconds
** TEST EXECUTE SUCCEEDED **
```

검증 포인트:
- 최근 카드(50) 탭 → 수정 시트 → 62로 변경 → 홈 카드가 62로 갱신, 50 사라짐.
- 오늘 점수 80 생성 → 캘린더 상세 → 삭제 → 확인 → 셀이 입력(생성) 모드로 복귀(=삭제 확인) → 재시작 후에도 삭제 유지.
- Bio 입력 → 저장 → 헤더에 표시 → **앱 재시작 후에도 유지**.

스크린샷: `docs/reports/sprint1-screenshots/` (S1-*, S2-*, S3-* = Sprint 1, 01~16 = 기존 회귀).

## 변경 파일
- `Scoor/ViewModels/HomeViewModel.swift`
- `Scoor/Views/Home/HomeView.swift`
- `Scoor/Views/Home/HomeSections.swift`
- `Scoor/ViewModels/MyPageViewModel.swift`
- `Scoor/Views/MyPage/MyPageView.swift`
- `Scoor/Models/User.swift`
- `Scoor/Services/UserServiceProtocol.swift`
- `Scoor/Services/MockUserService.swift`
- `ScoorUITests/ScoorSprint1UITests.swift` (신규)

## 남은 블로커
없음. 모든 Sprint 1 기능 구현 및 E2E 통과.

비고(블로커 아님):
- 사용자/프로필은 아직 `MockUserService`(+UserDefaults) 기반. bio는 현 아키텍처에서 안정적으로 영속되나, 향후 사용자 데이터의 SwiftData 이관 시 함께 옮기는 것을 권장.
- 기존 `ScoorPersistenceUITests`는 느슨한 셀렉터(`staticTexts["1"]`)를 사용 → 다른 테스트가 남긴 상태와 겹치면 모호해질 수 있음. 클린 상태/알파벳 순서(Persistence가 먼저 실행)에서는 정상 통과.
