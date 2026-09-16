# Scoor Admin

Scoor 운영 워크스페이스 (Next.js App Router).

- **실제 연결:** 관리자 인증, 운영 개요, 월드 토픽 작성·공개·마감, 공식 피드 등록·숨김·삭제.
- **샘플 미리보기:** 사용자, 분석, 알림, 월드 아젠다. 실제 운영 수치나 처리 상태가 아닙니다.
- 토픽·피드 목록 및 개요 집계는 각각 최근 200개 범위입니다.

## 실행

기존 `admin/.env.local` 연결을 유지한 상태에서 `npm install`, `npm run dev`를 실행합니다.
신규 환경에만 `.env.example`을 참고해 서버 환경변수를 설정하세요.

필수 서버 변수: `ADMIN_EMAIL`, `ADMIN_PASSWORD_SHA256` (64자리 SHA-256 hex),
`ADMIN_SESSION_SECRET` (32자 이상), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
이 값을 `NEXT_PUBLIC_*` 변수로 옮기지 마세요.

## 인증과 운영 범위

서버가 자격 증명을 확인하고 HMAC-SHA256 서명 세션을 HttpOnly/SameSite=Lax 쿠키에 저장합니다.
운영 모드에서는 Secure를 사용합니다. 세션은 로그인부터 7일간 유효합니다.
페이지는 `proxy.ts`, 데이터 API는 `requireAdmin()`이 보호합니다.
로그인·로그아웃 및 데이터 API는 교차 출처 요청을 거부합니다.

현재 단일 관리자 자격 증명 방식이며 MFA, IP 제한, 영속적인 로그인 속도 제한,
관리 작업 감사 로그, 자동 검열·발행 기능은 구현되어 있지 않습니다.
로그아웃은 브라우저 쿠키를 지우며, 이미 복사된 서명 토큰을 서버에서 개별 폐기하는 구조는 아닙니다.

## 검증

```bash
npm run lint
npm run build
```

`tests/auth-smoke.mjs`는 별도로 실행한 로컬 QA 서버에서만 수행합니다.
파일 상단의 `ADMIN_AUDIT_*` 변수를 지정해 실행하며, 허가된 콘텐츠 쓰기는 수행하지 않습니다.
UI 작성·삭제 테스트는 운영 Supabase가 아닌 분리된 테스트 백엔드를 사용해야 합니다.

상세 결과: [2026-09-06 어드민 점검](../docs/ADMIN-AUDIT-2026-09-06.md).
