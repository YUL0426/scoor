# Sprint 3/4 — 소셜 레이어 구현 리포트

작성일: 2026-06-08 · 브랜치: `sprint2-foundations`

## 개요

ClickUp(SSOT) 기준 소셜 레이어 7개 태스크(S3 World 3종 + S4 4종)를 구현했다.
기존에 UI/모델 골격만 있고 mock `@State`로만 동작하던 화면들을, **로컬 영속(SwiftData) 기반
서비스 레이어 + 뷰모델**로 연결했다. 백엔드가 레포에 없으므로, 기존 `SwiftDataScoreService`와
동일한 패턴(Protocol + Mock + SwiftData)으로 좋아요/댓글/월드점수/팔로우를 영속화했다.
완료 조건의 "백엔드 또는 로컬 모델"을 로컬 모델로 충족했고, 추후 서버 도입 시
`SocialServiceProtocol` 네트워크 구현만 추가하면 교체된다.

## 아키텍처

```
View ── ViewModel(@MainActor, LoadPhase 상태기계) ── SocialServiceProtocol
                                                       ├─ MockSocialService(인메모리: 프리뷰/테스트/기본)
                                                       └─ SwiftDataSocialService(영속: 프로덕션)
                                                            └─ SocialSeed(시드+페이지네이션+오버레이, 순수함수)
SwiftData @Model: LikeRecord · CommentRecord · WorldScoreRecord · FollowRecord
```

- **오버레이 전략**: 시드(MockFeed/MockWorld) 위에 영속된 좋아요/댓글 수를 덧입혀, 백엔드 없이도
  사용자 조작이 재시작 후 유지된다.
- **결정적 페이지네이션**: 페이지 1+는 FNV-1a 기반 결정적 UUID로 합성 → 무한 스크롤에서도
  좋아요/댓글이 안정적으로 붙는다.
- **낙관적 업데이트 + 롤백**: 좋아요/팔로우는 즉시 UI 반영 후 영속, 실패 시 되돌림.

## 태스크별 구현

| ClickUp | 구현 |
|---|---|
| [S3] World 토픽 피드 구축 | `WorldFeedViewModel` + `WorldView` 재연결. 페이지네이션/새로고침/카테고리·정렬/로딩·빈·에러 |
| [S3] 토픽 상세 화면 구축 | `TopicDetailView` 서비스 주입, 내 점수 영속 복원(`myWorldScore`) |
| [S3] World Scoor 작성 기능 | `TopicScoreSheet` → `submitWorldScore` 영속, 0~100 클램프, 코멘트 첨부, 재작성=마지막값 |
| [S4] 피드 타임라인 구축 | `FeedViewModel` + `FeedView`. 무한 스크롤/pull-to-refresh/정렬·필터/상태 |
| [S4] 좋아요 기능 구축 | `LikeRecord` 영속 + 낙관적 토글 + 롤백, 시드 카운트 오버레이 |
| [S4] 댓글 기능 구축 | `CommentRecord` + `CommentsSheet` 작성/수정/삭제, 카드 카운트 동기화 |
| [S4] 사용자 탐색 기능 구축 | `DiscoverView` + `DiscoverViewModel`: 인기/추천 사용자 + 추천 콘텐츠 + 팔로우 |

## 신규/수정 파일

신규: `Models/SocialModels.swift`, `Models/SocialPersistence.swift`,
`Services/SocialServiceProtocol.swift`, `Services/SocialSeed.swift`,
`Services/SwiftDataSocialService.swift`, `Services/MockSocialService.swift`,
`ViewModels/{FeedViewModel,WorldFeedViewModel,DiscoverViewModel}.swift`,
`Views/Feed/CommentsSheet.swift`, `Views/Discover/DiscoverView.swift`,
`ScoorTests/SocialServiceTests.swift`, `ScoorUITests/ScoorSprint3SocialUITests.swift`

수정: `Services/AppServices.swift`(socialService 주입), `ScoorApp.swift`(ModelContainer 스키마 +
UI테스트 격리 wipe), `ContentView.swift`(서비스 주입), `Views/Feed/{FeedView,FeedCardView,ReactionBarView}.swift`,
`Views/World/{WorldView,WorldPostCardView,TopicDetailView,TopicScoreSheet}.swift`

## 검증 evidence

- **빌드**: `xcodebuild build -scheme Scoor` → **BUILD SUCCEEDED**
- **유닛 테스트**: `ScoorTests/SocialServiceTests` → **9/9 통과**
  (좋아요 토글 영속·복원, 토글2회=원상복귀, 댓글 CRUD, 빈 댓글 거부, 월드점수 클램프·재작성,
  탐색 정렬, 팔로우 토글·추천 필터, 페이지네이션 결정성)
- **E2E UI 테스트**: `ScoorUITests/ScoorSprint3SocialUITests` → **통과**
  (Feed 타임라인 → 탐색 진입 → 팔로우 토글 → World 피드)
- **런타임 부팅**: 신규 SwiftData 스키마 정상 로드, 크래시 없음
- **스크린샷**: `docs/reports/sprint3-social-screenshots/`

## 남은 리스크 / 후속

- 추천 로직은 시드 기반 휴리스틱(평균점수/활동량). 실서버 추천 API로 교체 예정(프로토콜 분리됨).
- 댓글 작성자 식별은 현재 `MockUserService` 닉네임 기준. 실계정/인증 연동 시 정합 필요.
- 기존 `WorldViewModel`(월드 지도/국가 피드)과 본 작업의 `WorldFeedViewModel`(토픽 피드)은
  별개 화면 — 태스크 설명의 "WorldViewModel mock"은 토픽 피드(WorldView)의 mock `@State`를 지칭.
- 영속은 로컬 단일 기기. 멀티 기기 동기화는 서버 도입 시.
