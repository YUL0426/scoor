# spec-13 Phase 1 — 검증 상태 보고

날짜: 2026-07-19 · 브랜치: `feat/spec-13-phase1-backend` · PR: #2
프로젝트: `ebxdbadcejbytixumxrj` (scoor, ap-northeast-2 / 서울)

> **Phase 1은 아직 완료가 아니다.** 서버 왕복 검증(E2E)이 남아 있고, 그 전제인
> 마이그레이션 적용이 사용자 자격증명을 필요로 한다. 아래에 검증된 것과 남은
> 것을 분리해 적는다.

---

## 1. 전제 정정 — Phase 0는 착수된 적이 없었다

`docs/P0-RELEASE-BLOCKERS.md`는 P0 10건을 전부 ✅로 표시하지만, 서버가 필요한
항목은 **기기 로컬 우회**로 처리된 것이었다.

| 항목 | 당시 처리 | 실제 상태 |
|---|---|---|
| P0-2 이메일 가입 | Keychain + PBKDF2 | 기기 안에만 존재하는 계정 |
| P0-7 기록 고아화 | 이메일 해시 → 결정적 UUID | 같은 기기에서만 복원 |
| P0-6 게스트북 | SwiftData 로컬 | 기기 밖으로 나가지 않음 |
| P0-4 계정 삭제 | 로컬 데이터 삭제 | 서버 계정·Apple 토큰 미폐기 |
| P0-1 가짜 소셜 | "미리보기" 배너 | 여전히 시드 데이터 |

Phase 1(동기화 + World)은 이 전부를 전제하므로 단독 진행이 불가능했다. 그래서
Phase 0 기반 공사를 함께 수행했다.

---

## 2. 검증 완료 ✅

### 2.1 스키마 — 로컬 Postgres 17에서 실제 실행

`auth` 스키마 심(shim)을 만들어 마이그레이션 3종을 실행하고 **동작 테스트
20건을 전부 통과**시켰다. 문법 검증이 아니라 정책이 의도대로 동작하는지의 검증이다.

| # | 검증 항목 | 결과 |
|---|---|---|
| 1a/1b | 가입 트리거가 프로필 자동 생성, username 제약 만족 | PASS |
| 2a–2c | scores 소유자 격리 — B는 A의 기록을 읽지도 쓰지도 못함 | PASS |
| 3a/3b | LWW — 오래된 쓰기 무시, 최신 쓰기 반영 | PASS |
| 4a–4e | draft 토픽 비노출, closed 토픽 쓰기 거부, 재제출=수정 | PASS |
| 5a–5c | 차단 — 차단자에게만 콘텐츠 사라짐, 차단 사실은 대상에게 비노출 | PASS |
| 6a/6b | 신고 — 삽입만 가능, 신고자가 되읽을 수 없음 | PASS |
| 7a/7b | k-익명성 — n<5 지역 비노출, n=5에서 노출 | PASS |
| 8a | 계정 삭제 CASCADE (완전 삭제 결정) | PASS |

### 2.2 검증 중 발견해 고친 결함 3건

이 결함들은 SQL을 실제로 돌려보지 않았다면 코드 리뷰로는 드러나지 않았을 것들이다.

1. **LWW가 서버에서 강제되지 않았다.** PostgREST의 upsert(`merge-duplicates`)는
   조건 없이 덮어쓴다. 기기 A가 비행기 모드에서 쌓아둔 **오래된** 쓰기를 나중에
   올리면, 기기 B가 그 사이에 기록한 **최신** 값을 덮어써 사용자가 방금 쓴 점수가
   조용히 사라진다. → `scores_lww` BEFORE UPDATE 트리거로 서버가 거부하게 했다.
2. **집계 뷰가 draft 토픽을 노출했다.** 뷰는 소유자 권한으로 실행되어 기저 테이블
   RLS를 우회한다. 어드민이 작성 중인 토픽의 집계가 앱에 샐 수 있었다.
   → 뷰 안에 `status in ('live','closed')` 필터를 직접 넣었다.
3. `count(ws.*)` 모호성 → `count(ws.id)`.

### 2.3 클라이언트

- 빌드 성공, **74 유닛 테스트 통과** (신규 16건).
- 신규 테스트가 잡는 것: 아웃박스 접힘/폐기/재기동 복원, **KST 자정 경계 day 키**
  (UTC 기준이면 기록이 하루 밀린다), 프로비저닝 판정, 재시도 분류.

---

## 3. 미검증 ⚠️ — 서버 왕복은 아직 하지 않았다

| 항목 | 막힌 이유 |
|---|---|
| 마이그레이션 실서버 적용 | `supabase db push`는 **DB 비밀번호**가 필요. CLI 토큰은 키체인 ACL로 보호되어 추출 불가(정상) |
| RLS 실서버 검증 | 위 선행 필요 |
| 점수 저장 → 업로드 → 재로그인 복원 E2E | 위 선행 + 이메일 확인 설정 |
| Apple/Google id_token 교환 | 대시보드에 provider 미설정 |
| account-delete Edge Function | 미배포 |

### E2E를 막는 두 번째 조건 (실측)

GoTrue를 직접 두드려 확인한 결과:

- `Confirm email`이 **켜져 있다** → 가입 직후 세션이 발급되지 않아 로그인 왕복 검증 불가.
- 이메일 도메인 검증이 있다 → `example.com`, `test.com`, `scoor.app`은 거부(`email_address_invalid`).
- 무료 티어 SMTP 발송 제한이 낮다 → 확인 메일이 필요한 상태로는 테스트 반복 불가.

> **부작용 고지:** 위 확인 과정에서 미확인(unconfirmed) 프로브 계정이
> 몇 개 생성되었다. `scoor-e2e-probe@*`, `probe-1@*` 형태이며 대시보드
> Authentication에서 삭제하면 된다.

---

## 4. 남은 작업 — 사용자 실행 필요

### 4.1 마이그레이션 적용 (본인 터미널)

```bash
cd /Users/yul/Desktop/Scoor/Scoor
supabase db push --dry-run   # 적용 대상 3건 확인
supabase db push             # DB 비밀번호 입력 프롬프트
```

CLI 로그인·링크는 이미 되어 있다(`ebxdbadcejbytixumxrj`). 비밀번호를 잊었다면
대시보드 → Settings → Database → Reset database password.

### 4.2 이메일 확인 끄기 (테스트 동안)

Authentication → Sign In / Providers → Email → **Confirm email OFF**.
베타 공개 전에는 다시 켜야 한다(계정 도용·스팸 방지).

### 4.3 그다음 (자동)

```bash
SUPABASE_HOST=ebxdbadcejbytixumxrj.supabase.co \
SUPABASE_ANON_KEY=<publishable key> \
  ./supabase/tests/e2e_rls.sh
```

실서버에서 RLS 격리·LWW·재로그인 복원을 검증한다.

---

## 5. Phase 1 완료까지 남은 코드 작업

- [ ] World 탭을 `RemoteWorldService`에 연결 (현재는 시드 데이터 그대로)
- [ ] 신고/차단 UI (World 코멘트) — App Store 1.2 요건, World 오픈과 **동시** 출시
- [ ] 커뮤니티 가이드라인 동의 화면 (최초 게시 전 1회)
- [ ] 설정: 마지막 동기화 시각, 차단 목록 관리
- [ ] 최초 로그인 시 로컬 → 서버 데이터 마이그레이션 (spec-13 §7)
- [ ] 어드민 토픽 큐레이션 (없으면 World가 빈 화면)
- [ ] `account-delete` Edge Function 배포 + Apple client secret 설정
- [ ] Apple/Google provider 대시보드 설정

---

## 6. 결론

**스키마와 동기화 로직은 검증되었고, 실서버 연결은 검증되지 않았다.**
로컬 Postgres 검증은 정책 논리를 증명하지만 배포된 프로젝트에 RLS가 실제로
켜져 있는지는 증명하지 못한다. 4.1/4.2를 마치면 남은 검증은 자동으로 돌릴 수 있다.

요청하신 기준("실제 동기화와 인증 테스트까지 통과한 뒤 완료 보고")에 따라
**Phase 1은 미완료로 보고한다.**
