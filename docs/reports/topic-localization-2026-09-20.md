# 운영 토픽 현지화 — 2026-09-20

## 반영 범위

운영 토픽은 한국어 원문과 별도로 영어, 일본어, 중국어 간체, 독일어, 프랑스어, 브라질 포르투갈어, 스페인어 번역을 제공합니다. 현재 공개 토픽 5개와 초안 1개의 제목·설명·0점/100점 기준을 번역했습니다. 사용자 글과 토픽 ID, 기존 참여 기록, 점수 방향은 유지합니다.

iOS는 앱이 선택한 번들 언어에 맞춰 World 목록, 상세, 점수 입력, 반응 피드의 토픽명과 토픽 검색에 같은 번역을 사용합니다. 지역별 언어 코드를 정규화하며 번역이 없는 과거/커뮤니티 토픽은 영어 → 원문 순으로 대체합니다. 한국어는 원문을 사용합니다.

관리자 코드에는 기존 토픽 번역 편집과 신규 토픽의 7개 언어 입력 기능을 추가했습니다. 운영 토픽을 공개·마감하려면 모든 언어의 제목/점수 기준, 원문이 있는 경우 설명까지 필요합니다. 원문을 바꾸면 번역은 무효화됩니다. 관리자 화면은 로컬 격리 환경에서 확인했으며, 원격 관리자 사이트 배포는 수행하지 않았습니다. 번역은 자동 생성 서비스가 아니라 운영자가 검토·저장하는 콘텐츠입니다.

## 운영 DB 적용

- `20260920000001_topic_localizations.sql`을 운영 프로젝트에 적용하고 마이그레이션 이력을 기록했습니다.
- 별도로 미적용 중인 `20260915000007_pg_net_queue_access.sql`은 이번 작업에서 실행하지 않았습니다.
- `topics.translations` JSONB, 형태/길이 검사, 공개 전 번역 완성도 검사, `topics_feed` 번역 열, `search_localized_topics` RPC를 추가했습니다.
- 기존 토픽 6개 × 7개 언어 = **42개 번역**. 공개 5개/초안 1개 상태와 한국어 원문을 유지했습니다.
- 적용 전후 `topics=6`, `profiles=4`, `world_scores=0`으로 동일합니다. 사용자 데이터 삭제나 테스트 점수 작성은 수행하지 않았습니다.
- 앱 아카이브의 공개 API 설정으로 공개 토픽 5개의 35개 번역을 비교하고 언어별 제목 검색을 모두 확인했습니다. 8개 언어의 초안 검색 비노출과 `%` 입력의 리터럴 검색을 확인했습니다.

## 검증

- 마이그레이션과 `supabase/tests/topic_localizations.sql`을 운영 DB의 롤백 트랜잭션으로 먼저 검사했습니다. 번역 형식, 게시 제한, 원문 변경 시 초기화, 영어/일본어/한국어 검색, 익명 조회 및 수정 차단을 검증했습니다.
- 관리자 TypeScript 검사, 변경 파일 ESLint, Next.js production build 통과. 격리된 관리자 API **15개 검사** 통과: 인증·출처 검사·입력 검증·번역 저장·원문 보존·누락 번역 게시 거부.
- 브라우저에서 영어 제목 저장 후 다시 열어 유지됨을 확인하고 일본어 전환도 확인했습니다. [관리자 화면](/Users/yul/Desktop/scoor-workspace/release/topic-localization-2026-09-20/admin-japanese-topic.png).
- iOS 단위 테스트 **159개 중 154개 통과, 5개 서버 통합 테스트 건너뜀, 실패 0개**. 언어 정규화, 누락 번역 fallback, ID/통계/사용자 원문 보존을 포함합니다.
- iPhone 17 Pro와 iPad Air 11-inch (M4), iOS/iPadOS 26.5에서 영어 World → 상세 → 점수 입력 UI 검사 각각 통과. fixture는 한국어 원문과 영어 번역을 함께 내려 앱의 번역 선택 경로를 검사합니다. iPad는 iPhone 호환 모드이며 심사 환경 M3/iPadOS 27.0과는 다릅니다.
- [iPhone 결과](/Users/yul/Desktop/scoor-workspace/release/topic-localization-2026-09-20/iphone.xcresult), [iPad 결과](/Users/yul/Desktop/scoor-workspace/release/topic-localization-2026-09-20/ipad.xcresult), [운영 API 결과](/Users/yul/Desktop/scoor-workspace/release/topic-localization-2026-09-20/live-api-verification.json).

## 재제출 빌드

최신 아카이브: **1.0(6)** — [Scoor-2026-09-20-Localized-topics.xcarchive](/Users/yul/Desktop/scoor-workspace/release/Scoor-2026-09-20-Localized-topics.xcarchive). 빌드 5에는 운영 토픽 번역 클라이언트가 없으므로 빌드 6을 사용해야 합니다.

Release archive 성공, 코드 서명 검사 통과, `UIDeviceFamily=[1]`, 영어 번들 615개 값 중 한국어 잔존 0개, 운영 API 설정 포함, Debug fixture 주소/키/플래그 미포함을 확인했습니다. [검사 결과](/Users/yul/Desktop/scoor-workspace/release/topic-localization-2026-09-20/archive-verification.json).

Apple Development 서명 아카이브이며 Organizer에서 App Store Connect 배포 처리가 필요합니다. TestFlight 업로드·App Store 심사 제출·Apple 답변 전송은 하지 않았습니다. 실제 OAuth 로그인과 iPadOS 27.0 실기기 검사는 이번 자동 검증 범위에 포함하지 않습니다. 운영 토픽은 8개 언어를 제공하지만, 기존 전체 UI 번역률을 모든 언어에서 재검증했다는 의미는 아닙니다.
