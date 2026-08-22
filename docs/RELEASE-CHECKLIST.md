# 출시 체크리스트

2026-08-22 기준. `docs/P0-RELEASE-BLOCKERS.md`가 코드 이슈 목록이고
`docs/BACKEND-PHASE1-STATUS.md`가 백엔드 검증 보고서라면, 이 문서는
**"지금 스토어에 낼 수 있는가"** 하나만 본다.

검토 결론(2026-08-22): 코드 쪽 블로커는 이 브랜치에서 전부 닫혔고,
**남은 것은 전부 계정/콘솔 작업**이다 — §2가 그 목록이며 저장소 밖에서만 할 수 있다.

---

## 1. 이 브랜치에서 닫은 것

| # | 항목 | 무엇을 했나 | 검증 |
|---|---|---|---|
| 1 | 개인정보처리방침·약관이 부정확 | 백엔드 도입 전 문구("서버에 올리지 않습니다")가 사실이 아니게 돼 있었다. 실제 동작에 맞춰 다시 쓰고 **한국어판**(`/privacy/ko`, `/terms/ko`)을 신설, 앱 링크를 한국어판으로 변경 | `npm run build` 통과 |
| 2 | `PrivacyInfo.xcprivacy` 부재 | 프라이버시 매니페스트 신설 (UserDefaults = CA92.1, 수집 항목 3종, 추적 없음). 서드파티 SDK가 0개라 이 파일 하나가 전체를 덮는다 | `plutil -lint` 통과, 빌드 포함 확인 |
| 3 | 계정 삭제가 실제 삭제를 보장하지 않음 | 서버 호출을 fire-and-forget `Task`에서 꺼내 **await + 실패 시 rethrow**로 바꿨다. 실패하면 기기 데이터를 지우지 않고 사용자에게 알린다 | 유닛 105건 통과 |
| 4 | Apple 토큰 폐기 미동작 | 삭제 시점에 `ASAuthorization`으로 **새 authorization code**를 받아 함수로 보내고, 함수가 Apple과 교환해 refresh token을 폐기한다. client secret은 팀 키(.p8)로 매 호출 서명 | 코드 완료 · §2-3 시크릿 등록 후 실기기 검증 필요 |
| 5 | Feed 탭 전체가 가짜 데이터 | `posts`/`post_likes`/`comments` + `feed_posts` 뷰 신설, `RemoteFeedService`로 실서버 연결. 어드민 `/admin/feed`에서 글 등록·숨김·삭제 | 로컬 Postgres 17 RLS 검증 **17/17 PASS** (`supabase/tests/feed_rls.sql`) |
| 6 | World 글 스트림이 가짜 데이터 | 토픽이 서버에서 오는 빌드에서는 시드 글 스트림 대신 **실토픽 목록**을 보여준다. "예시 콘텐츠" 배너와 가짜 펄스 티커도 그 빌드에서는 사라진다 | 빌드 통과 |
| 7 | 실피드에 신고·차단 없음 (Guideline 1.2) | 피드 카드와 댓글에 신고 메뉴, 첫 댓글 전 커뮤니티 가이드라인 동의 게이트 추가 | 빌드 통과 |
| 8 | 한국어 미번역 20건 | `Localizable.xcstrings`에 한국어 추가. 백엔드가 붙어 더 이상 사실이 아닌 문구("community feed is coming soon")는 교체 | 남은 미번역은 숫자 포맷 6건뿐 |

### 공식 글(`is_official`)이라는 개념에 대해

앱에는 아직 글 작성 UI가 없다(Phase 2). 그래서 출시 시점 피드는 어드민이 등록한 글로
시작하는데, 그 글은 **작성자가 없고 앱에서 "Scoor · 공식" 배지로 표시된다.** 운영자가
쓴 글에 사람 이름을 붙여 일반 사용자 글처럼 내보내면 P0-1이 지적한 가짜 소셜 데이터로
그대로 되돌아가기 때문이다. 이 구분은 스키마의 check 제약과 RLS 정책(일반 사용자는
`is_official = true`를 넣을 수 없다), 그리고 앱 렌더링 세 곳에서 강제된다.

사용자 글 경로는 스키마·RLS 모두 열려 있다 — Phase 2에서 작성 UI만 붙이면 된다.

---

## 2. 남은 것 — 계정/콘솔 작업 (저장소 밖)

아래는 전부 로그인 자격이 필요해 코드로 처리할 수 없다.

### 2-1. 마이그레이션 적용 ⚠ 가장 먼저

`supabase/migrations/20260822000007_feed.sql`이 아직 실서버에 적용되지 않았다.
적용 전까지 Feed 탭은 빈 화면이고 어드민 `/admin/feed`는 오류를 낸다.

```
supabase db push --linked
```

> 현재 이 저장소에 연결된 Supabase CLI 계정은 프로젝트 `ebxdbadcejbytixumxrj`에
> 접근 권한이 없다(`supabase projects list`에 나오지 않고, functions/secrets/db 호출이
> 전부 403). `supabase login`으로 프로젝트 소유 계정으로 바꾸거나, 대시보드 SQL
> 에디터에 파일 내용을 그대로 붙여넣어 실행한다.

적용 후 `supabase/tests/feed_rls.sql`의 시나리오를 실서버에서 한 번 확인하면 좋다.

### 2-2. 랜딩 배포 + DNS

`scoor.app`은 등록돼 있지만(googledomains NS) **A 레코드가 없어 접속이 안 된다.**
앱 설정의 개인정보처리방침·약관 링크가 죽은 링크이고, App Store Connect는 동작하는
개인정보처리방침 URL을 요구한다.

- `landing/`을 호스팅에 배포 (빌드는 통과 상태)
- 등록기관 콘솔에서 A/CNAME 레코드 연결
- 확인: `https://scoor.app/privacy/ko`, `https://scoor.app/terms/ko`

### 2-3. Edge Function 시크릿 (Apple 토큰 폐기)

`account-delete`는 배포돼 있지만 시크릿이 비어 있어 폐기 단계가 조용히 건너뛰어진다.

| 키 | 값 |
|---|---|
| `APPLE_CLIENT_ID` | `com.euro.Scoor` |
| `APPLE_TEAM_ID` | `G83W9HD6G7` |
| `APPLE_KEY_ID` | Apple Developer → Keys에서 만든 Sign in with Apple 키의 Key ID |
| `APPLE_PRIVATE_KEY` | 같은 키의 `.p8` 파일 내용 (PEM 전체) |

```
supabase secrets set --project-ref ebxdbadcejbytixumxrj APPLE_CLIENT_ID=... APPLE_TEAM_ID=... APPLE_KEY_ID=... APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"
supabase functions deploy account-delete
```

미리 만들어 둔 JWT를 `APPLE_CLIENT_SECRET`으로 넣어도 동작하지만 최대 6개월이면
만료되고, 만료돼도 삭제 자체는 성공하므로 조용히 고장난다. `.p8` 쪽을 권한다.

### 2-4. Auth 설정 (이메일 가입)

- **커스텀 SMTP**: 현재 확인 불가(2-1과 같은 권한 문제). Supabase 기본 SMTP는
  **시간당 2~3통** 제한이라 출시하면 이메일 가입이 바로 막힌다. Resend/SendGrid 등을
  연결할 것.
- **Site URL / Redirect URLs**: 프로덕션 도메인(`https://scoor.app`)으로 설정.
  현재 `config.toml`은 로컬 기본값(`http://127.0.0.1:3000`)이다.

### 2-5. Xcode / App Store Connect

- **Associated Domains**: `Scoor.entitlements`에 `applinks:scoor.app` 추가 후 AASA 검증
  (현재 `applesignin`만 있어 유니버설 링크가 동작하지 않는다)
- 앱 등록 후 `landing/lib/site.ts`의 `appStoreId` 입력, `STORE_STATUS.appStoreLive = true`
- **App Privacy 설문**: `Scoor/PrivacyInfo.xcprivacy`와 **동일하게** 답할 것 —
  이메일 주소 / 사용자 ID / 기타 사용자 콘텐츠, 모두 "앱 기능", 추적 없음.
  매니페스트와 설문이 어긋나는 것 자체가 리젝 사유다
- 심사 메모에 신고·차단 위치와 계정 삭제 경로를 적어 두면 1.2 / 5.1.1(v) 확인이 빨라진다

### 2-6. 어드민 배포 + 첫 콘텐츠

`/admin`이 로컬에만 있다. 배포하고 `ADMIN_EMAIL` / `ADMIN_PASSWORD_SHA256` /
`ADMIN_SESSION_SECRET` / `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`를 주입한다.

출시 전에 실제로 채워야 할 것:
- `/admin/topics` — live 토픽 3~5개 (§15-4)
- `/admin/feed` — 공식 글 몇 건. **글이 없으면 Feed 탭이 빈 화면이다**

---

## 3. 이번 출시에 포함하지 않는 것

의도적으로 남긴 것들이다. 숨겨 두었을 뿐 반쯤 동작하는 상태로 노출되지 않는다.

- **사용자 글 작성(share-day)** — Phase 2. 스키마·RLS는 준비돼 있다
- **탐색(Discover) / 팔로우** — Phase 3. 팔로우할 실사용자가 없어 진입점을 숨겼다
- **푸시 알림** — Phase 3
- **한국어 외 5개 언어(de/es/fr/ja/zh-Hans)** — 신규 문자열 20건이 아직 영어로 보인다.
  국내 우선 출시라 한국어만 채웠다
