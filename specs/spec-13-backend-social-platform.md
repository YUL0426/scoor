# SPEC-13: 백엔드 구축 & 소셜 레이어 실데이터 전환 기획서

> **Version:** 1.0
> **Date:** 2026-07-17
> **Status:** Planning
> **선행 문서:** [프로덕션 준비성 감사 보고서], Plan.md, spec-12 (Services Layer)
> **해결 대상:** 감사 P0-1(가짜 소셜), P0-2(가짜 이메일 가입), P0-3(Google 로그인 실패), P0-4(계정 삭제 부재), P0-6(게스트북 유실), P0-7(이메일 유저 데이터 고아화)

---

## 1. 개요

### 1.1 목표

Scoor의 소셜 레이어(Feed / World / Discover / Guestbook)를 하드코딩 시드 데이터에서
**실제 사용자 데이터 기반 서비스**로 전환한다. 이를 위해:

1. 실계정 시스템(Apple / Google / Email)과 서버 세션을 구축한다.
2. 개인 점수 기록을 서버에 동기화하되, **오프라인 우선(local-first)** 원칙을 유지한다.
3. 피드 게시·좋아요·댓글·팔로우·게스트북·월드 토픽 점수를 서버 영속으로 전환한다.
4. UGC 앱의 필수 요건(신고/차단/모더레이션, 계정 삭제)을 갖춰 App Store 심사를 통과한다.

### 1.2 설계 원칙

| 원칙 | 의미 |
|---|---|
| **Local-first** | 개인 저널링(점수 기록)은 네트워크 없이 100% 동작. 서버는 백업+소셜 공유 계층 |
| **Protocol-driven swap** | 기존 `ScoreServiceProtocol` / `SocialServiceProtocol` 계약을 유지하고 Remote 구현체만 추가 (spec-12 설계 의도 그대로) |
| **Share is opt-in** | 개인 점수는 기본 비공개. 피드 게시는 명시적 공유 행위로만 발생 |
| **Anonymous-friendly** | `LightIdentity.isAnonymous`를 1급 개념으로 — 게시 단위 익명 선택 |
| **Ship in slices** | 각 Phase가 단독으로 출시 가능한 상태를 유지 |

### 1.3 범위 제외 (Out of Scope)

- DM/채팅, 이미지·영상 업로드, 알고리즘 추천 피드(ML), 다국가 리전 분산
- 랜딩 페이지 개편 (딥링크 실값 반영만 Phase 1에 포함)
- 수익화(구독/광고)

---

## 2. 기술 스택 결정

### 2.1 권장안: Supabase (Managed Postgres + Auth + Realtime)

**선정 이유** (1인 개발 · iOS 우선 · 빠른 전환이 전제):

| 요구 | Supabase 해결 방식 |
|---|---|
| Apple/Google/Email 실인증 (P0-2, P0-3) | Auth 빌트인 — Sign in with Apple 네이티브 지원, 이메일+비밀번호 실구현 제공 |
| 계정 삭제 (P0-4) | Admin API `deleteUser` + CASCADE 스키마로 원클릭 구현 |
| 소셜 데이터 영속 | Postgres + Row Level Security(RLS)로 권한을 DB 계층에서 강제 |
| 실시간 펄스/피드 갱신 | Realtime(WebSocket) 구독 |
| 집계(도시 평균 등) | Postgres materialized view + pg_cron 갱신 |
| 어드민 대시보드 | 기존 Next.js admin이 service-role 키로 동일 DB 사용 |
| 서버 로직(피드 랭킹, 토큰 검증 보강) | Edge Functions (Deno/TypeScript) |

**대안 (비권장, 기록용):** NestJS/Vapor 자체 서버 + RDS.
통제력은 높지만 인증·인프라·운영을 전부 직접 구축해야 하며, 현 팀 규모에서 Phase 1 도달이 2~3개월 지연될 것으로 추정. 트래픽/요구가 Supabase 한계를 넘으면 Postgres는 그대로 들고 API 계층만 자체 서버로 분리하는 탈출 경로가 있다.

### 2.2 클라이언트 네트워킹

- 서드파티 SDK 최소화 기조 유지(현 PKCE 직접 구현과 동일 철학) → `supabase-swift` 공식 SDK 사용하되, 서비스 프로토콜 뒤에 격리해 교체 가능성 유지.
- 모든 Remote 서비스는 기존 프로토콜의 구현체로 작성: `RemoteScoreService`, `RemoteSocialService`, `RemoteGuestbookService`, `RemoteUserService`.

---

## 3. 데이터 모델 (Postgres 스키마)

### 3.1 계정/프로필

```sql
-- Supabase auth.users가 인증 원장. 프로필은 public 스키마에 미러.
create table profiles (
  id          uuid primary key references auth.users on delete cascade,
  username    text unique not null check (char_length(username) between 2 and 20),
  avatar_emoji text,                -- 온보딩 이모지 아바타
  avatar_url  text,                 -- 사진 아바타(Storage)
  bio         text check (char_length(bio) <= 160),
  country_code text,                -- ISO 3166-1, 옵션(수동 선택)
  city        text,                 -- 옵션(수동 선택)
  is_banned   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
```

- **로컬 identity 매핑:** 기존 `AuthenticatedIdentity.stableUserID`(provider+sub 해시)는 폐기하고 서버 발급 `auth.users.id`로 일원화. 최초 로그인 시 클라이언트가 로컬 UserDefaults 프로필(닉네임/이모지/bio)을 서버로 1회 업로드(§7 마이그레이션).

### 3.2 개인 점수 (동기화 대상)

```sql
create table scores (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles on delete cascade,
  day        date not null,                    -- "하루 1점수" 규칙의 키
  value      smallint not null check (value between 0 and 100),
  reason     text check (char_length(reason) <= 200),
  mood       text,                             -- Mood enum rawValue, nullable
  client_updated_at timestamptz not null,      -- 충돌 해결: last-write-wins
  created_at timestamptz not null default now(),
  unique (user_id, day)                        -- 서버에서도 규칙 강제
);
```

### 3.3 피드 (감정 커뮤니티)

```sql
create table posts (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid not null references profiles on delete cascade,
  score        smallint not null check (score between 0 and 100),
  message      text not null check (char_length(message) <= 280),
  primary_mood text not null,                  -- Mood rawValue
  extra_moods  text[] not null default '{}',
  weather      text,                           -- Weather rawValue, nullable
  is_anonymous boolean not null default false, -- LightIdentity.isAnonymous
  country_code text,                           -- 게시 시점 프로필 스냅샷
  city         text,
  source_day   date,                           -- 내 점수 기록에서 공유한 경우 해당 일자
  is_hidden    boolean not null default false, -- 모더레이션 숨김
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz                     -- soft delete
);

create table post_likes (
  post_id  uuid references posts on delete cascade,
  user_id  uuid references profiles on delete cascade,
  primary key (post_id, user_id)
);

create table post_empathy (                    -- 🫂🌙☀️💭 공감 (사용자당 1개)
  post_id  uuid references posts on delete cascade,
  user_id  uuid references profiles on delete cascade,
  kind     text not null,                      -- EmpathyReaction rawValue
  primary key (post_id, user_id)
);

create table comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts on delete cascade,
  author_id  uuid not null references profiles on delete cascade,
  text       text not null check (char_length(text) <= 280),
  is_anonymous boolean not null default false,
  edited_at  timestamptz,
  is_hidden  boolean not null default false,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
```

### 3.4 World (토픽 스코어링)

```sql
create table topics (
  id          uuid primary key default gen_random_uuid(),
  category    text not null,                   -- WorldCategory rawValue
  title       text not null,
  subtitle    text,
  cover_emoji text,
  status      text not null default 'live',    -- draft | live | closed
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_by  uuid,                            -- 어드민 큐레이션
  created_at  timestamptz not null default now()
);

create table topic_targets (                   -- 경기의 홈/어웨이/MVP 같은 하위 대상
  id        text not null,                     -- ScoorTarget.id (match | team:LAL | mvp)
  topic_id  uuid references topics on delete cascade,
  label     text not null,
  primary key (topic_id, id)
);

create table world_scores (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles on delete cascade,
  topic_id   uuid not null references topics on delete cascade,
  target_id  text not null,
  value      smallint not null check (value between 0 and 100),
  comment    text check (char_length(comment) <= 280),
  is_anonymous boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, topic_id, target_id)        -- 재제출 = 수정
);
```

> 클라이언트의 `submitWorldScore(topicTitle:...)`는 title 키를 쓰고 있으나 서버 전환 시 `topic_id`(UUID) 키로 변경한다. 토픽은 **어드민이 큐레이션**(생성/마감)하고 앱은 읽기+점수 제출만 한다.

### 3.5 소셜 그래프 / 게스트북

```sql
create table follows (
  follower_id  uuid references profiles on delete cascade,
  followee_id  uuid references profiles on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table guestbook_messages (              -- P0-6 해결: 서버 영속
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles on delete cascade,
  author_id    uuid not null references profiles on delete cascade,
  content      text not null check (char_length(content) <= 500),
  is_private   boolean not null default false,
  is_hidden    boolean not null default false,
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
```

### 3.6 신뢰와 안전 (App Store Guideline 1.2 필수)

```sql
create table reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles,
  target_type text not null,                   -- post | comment | guestbook | user | world_score
  target_id   uuid not null,
  reason      text not null,                   -- spam | abuse | self_harm | other
  detail      text,
  status      text not null default 'open',    -- open | reviewed | actioned | dismissed
  created_at  timestamptz not null default now()
);

create table blocks (
  blocker_id uuid references profiles on delete cascade,
  blocked_id uuid references profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
```

### 3.7 집계 (Pulse / 도시·국가 평균)

```sql
-- pg_cron으로 5분마다 refresh. 홈 라이브 피드/월드 펄스의 실데이터 소스.
create materialized view pulse_stats as
select
  count(*) filter (where created_at > now() - interval '15 min') as recording_now,
  avg(score) filter (where created_at > now() - interval '24 h')  as global_avg_24h,
  ...;

create materialized view city_stats as
select country_code, city,
       avg(score)::numeric(5,1) as avg_score,
       count(*) as post_count
from posts
where created_at > now() - interval '24 h' and not is_hidden
group by country_code, city
having count(*) >= 5;   -- k-익명성: 표본 5 미만 도시는 비노출
```

### 3.8 RLS 정책 요지

| 테이블 | 정책 |
|---|---|
| scores | 본인만 CRUD (`user_id = auth.uid()`) |
| posts | 읽기: 전체(숨김/삭제/차단 관계 제외) · 쓰기: 본인 · 수정/삭제: 본인 |
| comments, world_scores, guestbook | 동일 패턴. 게스트북 private은 수신자+작성자만 읽기 |
| profiles | 읽기: 전체(공개 필드) · 수정: 본인 |
| reports | 삽입: 인증 사용자 · 읽기: 서비스 롤(어드민)만 |
| blocks | 차단 당사자만 |

---

## 4. API 설계

Supabase 클라이언트 SDK(RLS 경유)를 기본으로 하고, 복합 로직만 Edge Function으로 노출한다.

### 4.1 기존 프로토콜 → 서버 매핑

| 클라이언트 계약 (유지) | 서버 구현 |
|---|---|
| `loadFeed(page:pageSize:)` | `GET feed` — **cursor 기반**(created_at+id)으로 내부 전환, 프로토콜 시그니처는 유지하고 Remote 구현이 커서를 내부 관리 |
| `setLike(postId:liked:)` | `post_likes` upsert/delete (멱등) |
| `comments(for:)` / `addComment` / `editComment` / `deleteComment` | `comments` CRUD. `authorSeed` 파라미터는 서버 profile로 대체(프로토콜 v2에서 제거) |
| `loadTopics()` / `loadWorldPosts` | `topics` + 최근 `world_scores` 조인 |
| `submitWorldScore` / `myWorldScore(s)` | `world_scores` upsert / 조회 |
| `loadDiscover()` | Edge Function `discover` — 추천 유저(활동 기반) + 트렌딩 mood 집계 |
| `isFollowing` / `setFollowing` | `follows` 조회/upsert — **userName 키를 user_id 키로 변경** |
| `saveScore` / `getScoreHistory` (ScoreService) | §5 동기화 프로토콜 |
| Guestbook 4종 | `guestbook_messages` CRUD |

### 4.2 Edge Functions (복합 로직)

| Function | 역할 |
|---|---|
| `POST /share-day` | 내 점수 기록 → 피드 게시 원자적 생성(스냅샷 복사, 익명 플래그) |
| `GET /feed?cursor=` | 랭킹 피드: 최신순 기본 + 인기/공감 정렬, 차단·숨김 필터 서버 적용 |
| `GET /pulse` | pulse_stats + city_stats 요약 (홈 라이브 피드 / 월드 펄스 실데이터) |
| `POST /account/delete` | **P0-4**: Apple 토큰 revoke(Apple 요구사항) → auth.users 삭제 → CASCADE |
| `POST /moderation/action` | 어드민 전용: 숨김/차단/경고 (service-role 검증) |

### 4.3 에러/버전 정책

- 모든 응답에 `x-scoor-min-build` 헤더 → 강제 업데이트 게이트(클라이언트가 하한 미달 시 업데이트 안내 화면).
- 클라이언트 오류 표준화: `AuthError`와 동형의 `APIError` enum(한국어/영어 현지화 카탈로그 경유 — 감사 후속과제 #1 연계).
- 쓰기 API 멱등성: 좋아요/팔로우/월드점수는 upsert 설계로 재시도 안전.

---

## 5. 점수 동기화 프로토콜 (Local-first)

개인 저널링은 오프라인 100% 동작을 유지한다. SwiftData가 항상 진실의 원천(UI 기준)이고 서버는 백업/멀티디바이스 계층.

```
[쓰기]  SwiftData 저장 (즉시, 기존 그대로)
        └→ SyncQueue에 upsert 작업 적재 → 온라인 시 배치 업로드
[읽기]  항상 로컬에서 (기존 그대로)
[풀]    앱 포그라운드/로그인 시 GET /scores?since=lastSyncedAt → 로컬 병합
[충돌]  (user_id, day) 단위 client_updated_at 비교 last-write-wins
        — 기존 "하루 1점수, 마지막 쓰기 승리" 규칙과 동일해 사용자 정신모델 불변
[삭제]  tombstone 방식: deleted_at 전파
```

- **네트워크 실패 = 무소음.** 동기화 실패는 사용자 플로우를 절대 막지 않고 다음 기회에 재시도. 설정 화면에 "마지막 동기화 시각"만 표시.
- 피드 게시(`share-day`)는 반대로 **온라인 필수** 작업 — 실패 시 명시적 에러+재시도 UI.

---

## 6. 인증 시스템 재구축

### 6.1 전환 내용

| 현재 (감사 결과) | 전환 후 |
|---|---|
| Apple: 실구현, 검증은 클라이언트 신뢰 | identityToken을 서버(Supabase Auth)가 JWKS 검증 |
| Google: `GIDClientID` 미제공으로 항상 실패 (P0-3) | Info.plist 관리 파일 도입(`INFOPLIST_FILE`) + GIDClientID 주입, id_token 서버 검증 |
| Email: 가짜 (520ms 딜레이, 비밀번호 미저장) (P0-2) | Supabase 이메일 인증 — 실가입/로그인/비밀번호 재설정/이메일 확인 |
| 세션: UserDefaults JSON, 만료 없음 | access JWT(1h) + refresh token, **Keychain 저장** (기존 KeychainStore 재사용) |
| 로그아웃: 로컬 id 재발급 → 이메일 유저 데이터 고아화 (P0-7) | 서버 계정 id 불변 — 어떤 provider든 재로그인 시 기록 복원 |
| 계정 삭제: 없음 (P0-4) | 설정 화면 "계정 삭제" → `/account/delete` → 서버+로컬 완전 삭제, Apple 토큰 revoke |

### 6.2 게스트 모드 (제품 결정 필요 ⚠)

**권장:** 로그인 없이 개인 저널링 허용(현 UX 유지), 소셜 행위(게시/좋아요/댓글/팔로우) 시점에 로그인 요구. 게스트 → 계정 승격 시 로컬 기록을 서버 계정에 귀속(§7). 이 결정은 온보딩 전환율과 직결되므로 Phase 0 착수 전 확정한다.

---

## 7. 기존 사용자 데이터 마이그레이션

현재 로컬에만 존재하는 데이터의 계정 귀속 절차 (최초 로그인 1회):

1. 로그인 성공 → 서버 `user_id` 확보.
2. 로컬 SwiftData `ScoreModel` 전체를 `client_updated_at=createdAt`으로 배치 업로드(서버 upsert, 충돌 시 최신 승리).
3. UserDefaults 프로필(닉네임/이모지/bio/성별)을 `profiles`로 1회 업로드. username 충돌 시 접미사 부여 후 변경 유도.
4. 로컬 `LikeRecord`/`CommentRecord`/`FollowRecord`/`WorldScoreRecord`는 시드 데이터 대상이므로 **서버로 이전하지 않고 폐기**한다 (시드 글 자체가 사라지므로 의미 없음). 마이그레이션 완료 플래그 저장 후 로컬 소셜 레코드 정리.
5. 실패 시: 플래그 미설정 → 다음 로그인 때 재시도. 업로드는 멱등.

---

## 8. 콜드 스타트 전략 (빈 피드 문제)

시드 제거 직후 피드가 텅 비는 "고스트 타운" 문제 대응:

1. **정직한 에디토리얼 콘텐츠:** 운영팀 계정(`Scoor Team` 뱃지 명시)이 어드민에서 데일리 프롬프트/토픽 게시. **일반 유저로 위장하는 가짜 계정은 금지** — 감사 P0-1의 재발이 된다.
2. **World 우선 오픈:** 피드보다 토픽 스코어링(익명 참여 장벽 낮음)을 먼저 활성화해 참여 데이터를 축적.
3. **표본 임계값 규칙:** 집계(도시 평균, 펄스)는 표본 n≥5일 때만 노출, 미달 시 "아직 데이터를 모으는 중" 상태 표시.
4. **초대 기반 클로즈드 베타:** TestFlight 단계에서 시드 커뮤니티(100~500명)를 형성한 뒤 공개.
5. 홈 라이브 피드 문구("Someone in Tokyo just recorded a 92")는 실데이터 `/pulse` 연동 전까지 **해당 섹션 자체를 숨긴다.**

---

## 9. 신뢰와 안전 (App Store UGC 필수 요건)

Guideline 1.2 준수를 위해 Phase 1(피드 쓰기 오픈)과 **동시에** 출시해야 하는 항목:

- [ ] 게시물/댓글/게스트북 **신고** 버튼 (reports 테이블)
- [ ] 사용자 **차단** (blocks — 피드/댓글/게스트북에서 즉시 필터)
- [ ] **커뮤니티 가이드라인** 동의 (최초 게시 전 1회)
- [ ] 어드민 **모더레이션 큐** (신고 24h 내 검토 목표 — Apple 요구)
- [ ] 금칙어/스팸 1차 필터 (Edge Function, 게시 시점)
- [ ] 자해/자살 키워드 감지 시 지역별 상담 리소스 안내 배너 (감정 기록 앱 특성상 필수적 배려)

개인정보:

- [ ] 개인정보처리방침·이용약관 실문서 작성 + 설정 화면 연결 (P0-5 동시 해결)
- [ ] 위치 정보는 **수동 선택(국가/도시)만** — GPS 미사용으로 권한/규제 부담 제거
- [ ] App Privacy 라벨 갱신 (수집: 이메일, 사용자 콘텐츠, 식별자)
- [ ] 데이터 내보내기(JSON) — 계정 삭제와 함께 제공 권장

---

## 10. 클라이언트 변경 사항 (iOS)

| # | 변경 | 관련 파일 |
|---|---|---|
| C1 | `RemoteScoreService` + SyncQueue 신설, `SwiftDataScoreService`는 로컬 캐시 역할로 유지 | Services/ |
| C2 | `RemoteSocialService: SocialServiceProtocol` 신설 — 프로토콜 v2에서 `authorSeed`·`userName` 키 제거, `topicId`/`userId` 키로 교체 | SocialServiceProtocol.swift |
| C3 | `RemoteGuestbookService` — MockGuestbookService 대체 (P0-6) | AppServices.swift |
| C4 | AuthService를 Supabase 세션으로 재배선, 토큰 Keychain 유지 | Services/Auth/ |
| C5 | 이메일 가입 화면을 실API 연결 + 이메일 확인/비번 재설정 플로우 추가 | SignupLoginOptionsView.swift |
| C6 | `INFOPLIST_FILE` 도입 + `GIDClientID` 주입 (BUG-002 해소) | project.pbxproj |
| C7 | 설정: 계정 삭제, 차단 목록 관리, 개인정보처리방침/약관 링크, 마지막 동기화 표시 | SettingsView.swift |
| C8 | 피드 게시 UI: 점수 기록 후 "피드에 공유할까요?" 스텝(익명 토글 포함) 신설 | ScoreHomeView 후속 화면 |
| C9 | 홈 라이브 피드/월드 펄스 → `/pulse` 실데이터 연동 (연동 전까지 섹션 숨김) | HomeViewModel.swift |
| C10 | 강제 업데이트 게이트 + 서버 점검 안내 화면 | RootFlowView |
| C11 | 네트워크 상태별 UI: 피드 오프라인 캐시 표시 + 재시도, 게시 실패 토스트 | FeedView 등 |

**어드민 (Next.js):**

| # | 변경 |
|---|---|
| A1 | mock 인증 폐기 → Supabase Auth(이메일+MFA) + `middleware.ts` 서버측 보호 + admin role claim 검증 (P0-8) |
| A2 | lib/mock → 실데이터: 유저 관리(정지/삭제), 모더레이션 큐, 토픽 큐레이션(생성/마감), 펄스 대시보드 |

---

## 11. 비기능 요구사항

| 항목 | 목표 |
|---|---|
| 피드 첫 페이지 p95 | < 600ms (서울 기준) |
| 점수 동기화 | 백그라운드, 사용자 체감 0 |
| 레이트 리밋 | 게시 5/min, 댓글 10/min, 신고 20/day (Edge Function 계층) |
| 가용성 | Supabase SLA 위임, 점검 모드 플래그(원격 구성) 지원 |
| 백업 | Postgres PITR 7일 + 일간 스냅샷 |
| 관측성 | Sentry(iOS+Edge) + Supabase 로그, 핵심 지표 대시보드(어드민 내) |
| 보안 | 전 구간 RLS, service-role 키는 서버(어드민 SSR/Edge)에만, 클라이언트엔 anon 키만 |

---

## 12. 단계별 로드맵

> 전제: 1인 개발 + Claude Code. 기간은 목표치이며 각 Phase 말에 TestFlight 배포.

### Phase 0 — 기반 공사 (3~4주)
- Supabase 프로젝트/스키마/RLS, **git 저장소 초기화(P0-9)** + CI(빌드/테스트)
- 실인증 3종 + 세션 + 계정 삭제 + 로컬 데이터 마이그레이션(§7)
- 개인정보처리방침/약관 실문서 + 설정 연결
- **출시 가능 상태:** "개인 저널링 + 실계정 + 클라우드 백업" 앱 (소셜 탭은 Coming Soon 처리)

### Phase 1 — 점수 동기화 + World 오픈 (3~4주)
- SyncQueue/충돌 해결, 멀티디바이스 복원 검증
- 토픽 큐레이션(어드민) + 월드 점수 제출/집계 실데이터화
- 신고/차단/가이드라인 v1 (World 코멘트에 적용)

### Phase 2 — 피드 오픈 (4~5주)
- share-day 게시 플로우(익명 토글), 피드 읽기/좋아요/공감/댓글
- 모더레이션 큐 + 금칙어 필터 + 자해 키워드 리소스 안내
- 펄스 집계 실데이터(k≥5 규칙), 홈 라이브 피드 재점등
- 클로즈드 베타(초대 코드) 시작

### Phase 3 — 소셜 그래프 (3주)
- 팔로우/Discover 실데이터, 게스트북 서버 전환(P0-6)
- 푸시 알림(댓글/게스트북) — APNs + devices 테이블

### Phase 4 — 공개 출시 준비 (2주)
- 딥링크 실값(AASA/팀ID/스토어ID) 반영, 랜딩 연결
- 부하 테스트, App Store 심사 제출 (UGC 요건 체크리스트 최종 점검)

**총 목표 기간: 약 15~18주 (Phase 0 종료 시점부터 언제든 부분 출시 가능)**

---

## 13. 성공 지표

| 지표 | Phase 2 베타 목표 |
|---|---|
| D7 리텐션 (점수 기록 유저) | ≥ 25% |
| 기록 → 피드 공유 전환율 | ≥ 15% |
| 신고 처리 SLA | 24h 내 100% |
| 동기화 실패율 | < 0.5% |
| 크래시 프리 세션 | ≥ 99.5% |

## 14. 리스크

| 리스크 | 대응 |
|---|---|
| 빈 피드로 초기 이탈 | §8 콜드 스타트 전략, World 우선 오픈, 초대 베타 |
| 감정 데이터 = 민감정보 인식 | 익명 기본 제공, 위치 수동 입력만, 공유 opt-in 명확화, 처리방침에 명시 |
| 모더레이션 리소스 부족(1인) | 임계값 자동 숨김(신고 3건), 어드민 모바일 대응, 베타 규모 통제 |
| Supabase 종속 | 표준 Postgres 스키마 유지, API는 프로토콜 뒤 격리 — 탈출 경로 확보 |
| 프로토콜 v2 전환 중 회귀 | 기존 Mock/SwiftData 구현 유지로 프리뷰·테스트 병행, 계약 테스트 추가 |

---

## 15. 착수 전 확정 필요 결정 (Open Questions)

1. **게스트 모드 허용 여부** (§6.2 — 권장: 허용, 소셜 행위 시 로그인)
2. 피드 익명 **기본값** (권장: 실명(닉네임) 기본 + 게시별 익명 토글)
3. 클로즈드 베타 규모/채널 (권장: 초대 코드 300명, 국내 우선)
4. World 토픽 운영 주기 (권장: 어드민 큐레이션 일 3~5개로 시작)
5. 삭제 계정의 게시물 처리 (권장: 익명화 유지 vs 완전 삭제 — **완전 삭제** 권장, CASCADE 단순성)
