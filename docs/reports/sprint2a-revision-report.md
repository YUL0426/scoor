# Sprint 2-A 개정 — 감정을 "파생 필드"로 전환

> 작성일: 2026-06-03 · 빌드: Xcode 26.1.1 · 시뮬레이터: iPhone 17 Pro (iOS 26.1)

## 배경 / 결정
Scoor의 핵심 입력은 **점수(Score) + 이유(Reason)** 두 가지로 한정한다. 사용자가 감정을 수동 선택하지 않는다. 감정(Mood)은 향후 **AI 감정분석 / 규칙기반 분류**로 **자동 파생**되는 필드가 된다. 기존 mood 저장구조·DB 필드·분석(표시) 구조는 보존한다.

## 권장 아키텍처
```
[사용자 입력]                     [파생 계층 (미래)]                 [영속/소비]
 Score + Reason   ──saveScore──▶  MoodAnalyzing                ──▶  Score.mood / ScoreModel.moodRaw
 (ScoreHomeView)                  ├ RuleBasedMoodAnalyzer (v1)        (동일 SwiftData 컬럼)
                                  └ AIMoodAnalyzer (LLM, 추후)   ──▶  소비: 캘린더 pill / 홈 최근 / 월간 리캡
```
- **Seam(이음새):** `MoodAnalyzing` 프로토콜 — `analyze(score:reason:) async -> Mood?`. 규칙기반/AI 구현을 동일 인터페이스로 교체.
- **현재 기본값:** `DisabledMoodAnalyzer`(항상 nil) → 동작 변화 없음, 신규 기록은 감정 없음.
- **v1 분류기:** `RuleBasedMoodAnalyzer`(키워드+점수밴드, 온디바이스·의존성 없음) — 드롭인 준비 완료, **아직 미연결**.
- **파생 시점(미래 2-B):** `saveScore` 직후 비동기 분석 → `moodRaw` 갱신, 또는 nil 항목 일괄 백필. 입력은 빠르게, 감정은 eventually-consistent.
- **읽기(소비) 계층은 이미 준비됨:** 캘린더 상세 pill·홈 최근 칩·My Page "이번 달 대표 감정"이 `mood != nil`일 때만 표시 → 분석이 채우면 자동 점등, 지금은 자연스럽게 숨김.
- **월간 리캡(미래):** 파생된 월간 mood 분포를 동일 read 모델에서 집계 → 공유 카드 생성.

## 수정 파일
**제거(입력에서 감정 선택)**
- `Scoor/Views/Score/ScoreHomeView.swift` — `moodSelector`/`MoodSelectChip`/"오늘의 감정" 칩 제거. (`reason-pill` 접근성 id 추가)
- `Scoor/ViewModels/ScoreInputViewModel.swift` — `@Published mood`·`toggleMood` 제거. 편집 시 기존 mood 보존(`existing.mood`), 신규는 nil.
- `Scoor/Models/Mood+Emotion.swift` — 미사용 `selectable` 제거(표시 헬퍼·Codable 유지).

**추가(미래 분석 아키텍처)**
- `Scoor/Services/MoodAnalyzing.swift` — 프로토콜 + `RuleBasedMoodAnalyzer` + `DisabledMoodAnalyzer`(문서화된 미연결 seam).

**테스트**
- `ScoorUITests/ScoorSprint2AUITests.swift` — 감정 선택 검증 → "선택기 부재 + 점수/이유만 + 파생 mood 미표시" 검증으로 개정.

**보존(미변경) — 호환/분석 구조 유지**
- `Scoor/Models/Score.swift`(`mood`), `Scoor/Models/ScoreModel.swift`(`moodRaw`), `ScoreEntry.mood`, 매핑.
- 표시 계층: `HomeSections.swift`(최근 칩), `MyPageView.swift`(상세 pill·월간 요약), `HomeViewModel`/`MyPageViewModel` 집계.

## 마이그레이션 영향
- **DB 스키마 변경 없음.** `ScoreModel.moodRaw`는 그대로 유지 → 추가/롤백 모두 마이그레이션 불필요(컬럼 변동 0).
- **기존 데이터 100% 호환:** 2-A에서 감정이 기록된 레코드는 그대로 로드/표시되고, 편집해도 보존(`existing.mood`). nil 레코드는 평소대로 동작.
- **신규 레코드:** mood = nil(파생 전). 분석 연결 시 동일 컬럼에 채워짐.

## Sprint 2-A 롤백 범위
| 구분 | 항목 | 상태 |
|---|---|---|
| **롤백(제거)** | 점수 입력의 감정 선택 UI(`moodSelector`/`MoodSelectChip`) | 제거됨 |
| **롤백(제거)** | VM의 사용자 감정 입력 배선(`mood` 발행/`toggleMood`) | 제거됨 |
| **롤백(제거)** | 미사용 `Mood.selectable` | 제거됨 |
| **유지** | `Score.mood`·`ScoreModel.moodRaw`·`ScoreEntry.mood`·매핑 | 보존 |
| **유지** | 감정 표시 계층(캘린더/홈/My Page) — 파생값 소비자 | 보존(파생 시 점등) |
| **유지** | `Mood+Emotion.swift`(Codable+표시 헬퍼) | 보존 |
| **신규** | `MoodAnalyzing` seam(규칙기반/AI/disabled) | 추가 |

즉, **롤백은 "입력측 수동 선택"에 국한**되고, 저장·분석·표시 구조는 전부 유지하여 미래 자동화 준비를 마쳤다.

## QA 결과 (전체 스위트, 클린)
```
Executed 6 tests, with 0 failures (0 unexpected) in 240.7s
** TEST EXECUTE SUCCEEDED **
```
| 테스트 | 결과 |
|---|---|
| `ScoorPersistenceUITests`(Sprint 0) | ✅ |
| `ScoorSprint1UITests` ×3 | ✅ |
| `Sprint2A/test1NoEmotionSelectorScoreAndReasonOnly` | ✅ |
| `Sprint2A/test2RecordPersistsWithNoDerivedMood` | ✅ |

스크린샷: `docs/reports/sprint2a-revised-screenshots/`
- `S2Arev-01` 점수 시트: 점수+이유만(감정 선택기 없음)
- `S2Arev-02` 이유 입력
- `S2Arev-03` 기록 후 홈
- `S2Arev-04` 캘린더 상세: 파생 mood 미표시

## 남은 이슈
- 파생 분석은 **미연결**(의도). 2-B에서 `MoodAnalyzing`을 `AppServices`에 주입하고 `saveScore` 후 파생/백필로 연결 필요.
- `RuleBasedMoodAnalyzer`는 로직 유닛테스트 권장(현재 UI 테스트 타깃만 존재 → 유닛 테스트 타깃 신설 또는 SwiftTesting 도입 시 추가).
- 이유 입력 placeholder 문구("오늘의 감정을 한 줄로…")가 '감정' 단어를 포함 → 자유 텍스트 이유 필드임. 카피 정리 여지(선택).
