# Sprint 2-A — 감정 입력 시스템 구현 및 E2E QA 리포트

> 작성일: 2026-06-03 · 빌드: Xcode 26.1.1 · 시뮬레이터: iPhone 17 Pro (iOS 26.1)

## 범위
일일 Scoor에 **구조화된 감정(Mood) 태그**를 추가. 기존 Feed `Mood` enum 재사용, `Score`/`ScoreModel` 안전 확장(기존 SwiftData 레코드 보존), 입력 UI + 표시(홈 최근/캘린더 상세/My Page 요약), E2E 테스트.

제약 준수: 알림·리캡 미구현 / UI 리디자인 없음 / Feed·World 미변경(공유 모델 재사용 한정) / Sprint 0·1 동작 보존.

## 구현 요약
- **Mood 재사용:** 신규 `Models/Mood+Emotion.swift`에 `extension Mood: Codable {}`(rawValue 합성) + emoji/SF Symbol/tint 표시 헬퍼. **`FeedModels.swift`는 미변경**(Feed 도메인 불간섭).
- **모델 확장:** `Score`에 `mood: Mood?`(옵셔널), `ScoreEntry`에 `mood`. `ScoreModel`에는 **옵셔널 `moodRaw: String?`** 추가 → 순수 추가형 lightweight 마이그레이션.
- **입력:** `ScoreInputViewModel`에 `mood` 상태·로드·저장·`toggleMood`. `ScoreHomeView`에 가로 스크롤 감정 칩 행("오늘의 감정") 추가(점수↔이유 사이). 선택은 옵셔널, 재탭 시 해제.
- **표시:** 홈 최근 카드 감정 칩 / 캘린더 상세 감정 pill / My Page "이번 달 대표 감정" 요약 카드.

## 마이그레이션 처리
- **방식:** `ScoreModel`에 **옵셔널 속성 1개(`moodRaw: String?`)만 추가**. SwiftData의 **자동 lightweight 마이그레이션** 범위 → `VersionedSchema`/`MigrationPlan` 불필요. 기존 행은 `moodRaw = nil`로 디코딩.
- **매핑:** `Score.mood?.rawValue ↔ ScoreModel.moodRaw`, 복원 시 `Mood(rawValue:)`. 잘못된 값은 `nil`로 안전 폴백.
- **실데이터 검증:** 직전 스프린트가 **구(舊) 스키마**(moodRaw 없음)로 기록한 시뮬레이터 SwiftData 스토어를 **삭제하지 않고** 신(新) 빌드로 실행 → `test2`(감정 기록 + 재시작 후 영속) **통과**. 즉 구 레코드가 정상 로드되고 신규 감정 레코드가 함께 보존됨을 실증.

## QA 결과

**전체 스위트 · 클린 상태**
```
Executed 6 tests, with 0 failures (0 unexpected) in 242.4s
** TEST EXECUTE SUCCEEDED **
```
| 테스트 | 결과 |
|---|---|
| `ScoorPersistenceUITests` (Sprint 0 회귀) | ✅ PASS |
| `ScoorSprint1UITests` × 3 (recent edit / delete / bio) | ✅ PASS |
| `ScoorSprint2AUITests/test1EmotionCreateAndDisplay` | ✅ PASS |
| `ScoorSprint2AUITests/test2EmotionRecentCardAndPersist` | ✅ PASS |

**마이그레이션 전용 런(구 스키마 스토어, 미삭제):** `test2` ✅ PASS — 마이그레이션 안전성 실증.

검증 포인트: 감정 선택 저장 → 캘린더 상세 pill 표시 → My Page 월간 대표 감정 집계 → 홈 최근 카드 표시 → **앱 재시작 후 감정 영속**.

## 스크린샷 (`docs/reports/sprint2a-screenshots/`)
- `S2A-00` 점수 시트의 감정 선택기(오늘의 감정 칩)
- `S2A-01` 감정 포함 오늘 기록 후 홈
- `S2A-02` My Page "이번 달 대표 감정" 요약
- `S2A-03` 캘린더 상세의 감정 pill
- `S2A-04` 과거 날짜 감정 기록
- `S2A-05` 홈 최근 카드 감정
- `S2A-06` 재시작 후 감정 영속

## 변경 파일
신규: `Scoor/Models/Mood+Emotion.swift`, `ScoorUITests/ScoorSprint2AUITests.swift`
수정: `Scoor/Models/Score.swift`, `Scoor/Models/ScoreModel.swift`, `Scoor/ViewModels/HomeViewModel.swift`, `Scoor/ViewModels/StatsViewModel.swift`, `Scoor/ViewModels/ScoreInputViewModel.swift`, `Scoor/ViewModels/MyPageViewModel.swift`, `Scoor/Views/Score/ScoreHomeView.swift`, `Scoor/Views/Home/HomeSections.swift`, `Scoor/Views/MyPage/MyPageView.swift`

## 남은 이슈
- 통계 상세 화면(`StatsView`)에는 감정 분포를 아직 추가하지 않음(요구사항의 "Stats 또는 My Page 요약 — 가능하면" 중 My Page로 충족). 향후 감정 트렌드/분포 차트로 확장 가능.
- `Mood` 라벨/카피는 Feed에서 유래(행복/번아웃/…). 개인 감정 분류로서의 카피 톤은 추후 제품 검토 여지.
- 기존 `ScoorPersistenceUITests`의 느슨한 셀렉터(`staticTexts["1"]`)는 클린/순서 보장 시에만 안전(Sprint 1 리포트에 기록한 기존 이슈, 본 스프린트 무관).
