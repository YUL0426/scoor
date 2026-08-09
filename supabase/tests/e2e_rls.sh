#!/usr/bin/env bash
# 실서버 RLS / 동기화 계약 검증 (spec-13 Phase 1).
#
# 앱이 실제로 호출하는 것과 같은 PostgREST/GoTrue 엔드포인트를 그대로 두드린다 —
# 로컬 Postgres 검증이 스키마 논리를 증명한다면, 이 스크립트는 배포된 프로젝트에
# RLS가 실제로 켜져 있는지를 증명한다.
#
# 사전 조건:
#   1. supabase db push 로 마이그레이션이 적용되어 있을 것
#   2. supabase CLI가 로그인·링크되어 있을 것
#
# "Confirm email"이 켜져 있어도 동작한다 — 가입 직후 세션이 없으면 CLI(Management
# API)로 테스트 계정만 확인 처리하고 정상 로그인 경로로 진행한다. 프로덕션 설정을
# 바꾸지 않으므로 검증 때문에 인증을 약화시킬 일이 없다.
#
# 사용법:
#   SUPABASE_HOST=<ref>.supabase.co SUPABASE_ANON_KEY=<publishable key> \
#     ./supabase/tests/e2e_rls.sh

set -uo pipefail

HOST="${SUPABASE_HOST:?SUPABASE_HOST 환경변수가 필요합니다}"
KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY 환경변수가 필요합니다}"
BASE="https://$HOST"

PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check(){ [ "$1" = "$2" ] && ok "$3" || bad "$3 (기대=$1 실제=$2)"; }

jqv() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1','') if isinstance(d,dict) else '')" 2>/dev/null; }
count() { python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d) if isinstance(d,list) else -1)" 2>/dev/null; }

# 매 실행마다 새 계정 — 재실행이 이전 상태에 걸리지 않게.
STAMP="$(date +%s)"
EMAIL_A="scoor-e2e-a-$STAMP@gmail.com"
EMAIL_B="scoor-e2e-b-$STAMP@gmail.com"
PASSWORD="E2e-test-$STAMP-pw"

signup() {
  curl -sS -m 20 -X POST "$BASE/auth/v1/signup" \
    -H "apikey: $KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}
signin() {
  curl -sS -m 20 -X POST "$BASE/auth/v1/token?grant_type=password" \
    -H "apikey: $KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}
rest() { # method path token [body]
  local m="$1" p="$2" t="$3" b="${4:-}"
  if [ -n "$b" ]; then
    curl -sS -m 20 -X "$m" "$BASE/rest/v1/$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $t" \
      -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates,return=representation" -d "$b"
  else
    curl -sS -m 20 -X "$m" "$BASE/rest/v1/$p" -H "apikey: $KEY" -H "Authorization: Bearer $t"
  fi
}

# 테스트 계정을 GoTrue 가입 대신 SQL로 만든다.
#
# 가입 엔드포인트는 확인 메일을 보내려 하고, 무료 티어 SMTP 한도(시간당 소수)에
# 즉시 걸려 테스트를 반복할 수 없다. 계정을 직접 넣으면 메일 경로를 건드리지 않고,
# 프로덕션의 Confirm email 설정도 끌 필요가 없다. 비밀번호는 GoTrue와 같은 bcrypt로
# 저장하므로 이후 로그인은 실제 인증 경로를 그대로 탄다.
seed_user() {
  supabase db query --linked "
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      -- GoTrue는 이 토큰 컬럼들을 non-nullable 문자열로 읽는다. NULL로 두면
      -- 로그인 시 'Database error querying schema'로 실패한다.
      confirmation_token, recovery_token, email_change, email_change_token_new,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', gen_random_uuid(),
      'authenticated', 'authenticated', '$1', crypt('$PASSWORD', gen_salt('bf')),
      now(), now(), now(), '{\"provider\":\"email\",\"providers\":[\"email\"]}', '{}',
      '', '', '', '', '', '', '', ''
    ) returning id" 2>/dev/null \
  | python3 -c "import sys,json,re;m=re.search(r'\{.*\}',sys.stdin.read(),re.S);d=json.loads(m.group(0)) if m else {};r=d.get('result') or d.get('rows') or [];print(r[0]['id'] if r else '')"
}

echo "== 0. 테스트 계정 생성 (SQL) =="
UID_A="$(seed_user "$EMAIL_A")"
UID_B="$(seed_user "$EMAIL_B")"
[ -n "$UID_A" ] && [ -n "$UID_B" ] || { echo "  계정 생성 실패 — CLI 링크 상태를 확인하세요."; exit 1; }
ok "A/B 계정 생성 (A=$UID_A)"

echo "== 0b. 실제 로그인 경로로 세션 발급 =="
TOKEN_A="$(signin "$EMAIL_A" | jqv access_token)"
TOKEN_B="$(signin "$EMAIL_B" | jqv access_token)"
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] || { echo "  로그인 실패: $(signin "$EMAIL_A" | head -c 200)"; exit 1; }
ok "A/B 세션 발급 (GoTrue password grant)"

echo "== 1. 가입 트리거: 프로필 자동 생성 =="
check 1 "$(rest GET "profiles?id=eq.$UID_A&select=id,username" "$TOKEN_A" | count)" "A의 프로필이 생성됨"

echo "== 2. scores RLS: 소유자만 =="
rest POST "scores?on_conflict=user_id,day" "$TOKEN_A" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-19\",\"value\":72,\"reason\":\"E2E\",\"client_updated_at\":\"2026-07-19T10:00:00Z\"}]" >/dev/null
check 1 "$(rest GET "scores?select=day,value" "$TOKEN_A" | count)" "A가 자기 점수를 읽음"
check 0 "$(rest GET "scores?select=day,value" "$TOKEN_B" | count)" "B는 A의 점수를 볼 수 없음"

RESP="$(rest POST "scores?on_conflict=user_id,day" "$TOKEN_B" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-18\",\"value\":1,\"client_updated_at\":\"2026-07-19T10:00:00Z\"}]")"
echo "$RESP" | grep -q "42501\|violates row-level security" \
  && ok "B가 A의 계정에 쓰기 시도 → 차단됨" \
  || bad "B가 A의 계정에 썼습니다: $(echo "$RESP" | head -c 120)"

echo "== 3. Last-write-wins 트리거 =="
rest POST "scores?on_conflict=user_id,day" "$TOKEN_A" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-19\",\"value\":10,\"client_updated_at\":\"2026-07-19T09:00:00Z\"}]" >/dev/null
V="$(rest GET "scores?day=eq.2026-07-19&select=value" "$TOKEN_A" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['value'])" 2>/dev/null)"
check 72 "$V" "오래된 쓰기(09:00)는 무시됨"

rest POST "scores?on_conflict=user_id,day" "$TOKEN_A" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-19\",\"value\":88,\"client_updated_at\":\"2026-07-19T11:00:00Z\"}]" >/dev/null
V="$(rest GET "scores?day=eq.2026-07-19&select=value" "$TOKEN_A" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['value'])" 2>/dev/null)"
check 88 "$V" "최신 쓰기(11:00)는 반영됨"

echo "== 4. 재로그인 후 복원 (P0-7의 진짜 해결) =="
TOKEN_A2="$(signin "$EMAIL_A" | jqv access_token)"
[ -n "$TOKEN_A2" ] && ok "A 재로그인 성공" || bad "A 재로그인 실패"
V="$(rest GET "scores?day=eq.2026-07-19&select=value" "$TOKEN_A2" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['value'])" 2>/dev/null)"
check 88 "$V" "재로그인 세션에서 기록이 그대로 복원됨"

echo "== 5. topics: 익명 읽기 가능, 사용자 쓰기 불가 =="
ANON_CODE="$(curl -sS -m 20 -o /dev/null -w "%{http_code}" "$BASE/rest/v1/topics?select=id" -H "apikey: $KEY")"
check 200 "$ANON_CODE" "익명이 토픽 목록을 읽음"
RESP="$(rest POST "topics" "$TOKEN_A" "[{\"category\":\"tech\",\"title\":\"해킹 시도\"}]")"
echo "$RESP" | grep -q "42501\|violates row-level security" \
  && ok "일반 사용자는 토픽을 만들 수 없음(어드민 전용)" \
  || bad "일반 사용자가 토픽을 만들었습니다: $(echo "$RESP" | head -c 120)"

echo "== 6. reports: 삽입만 가능, 조회 불가 =="
rest POST "reports" "$TOKEN_B" \
  "[{\"reporter_id\":\"$UID_B\",\"target_type\":\"user\",\"target_id\":\"$UID_A\",\"reason\":\"spam\"}]" >/dev/null
RESP="$(rest GET "reports?select=id" "$TOKEN_B")"
if echo "$RESP" | grep -q "42501\|permission denied" || [ "$(echo "$RESP" | count)" = "0" ]; then
  ok "신고자가 신고 내역을 되읽을 수 없음"
else
  bad "신고 내역이 노출됨: $(echo "$RESP" | head -c 120)"
fi

echo "== 7. account-delete Edge Function: 실제 계정 삭제 =="
# SQL DELETE가 아니라 앱이 실제로 호출하는 Edge Function 경로를 그대로 탄다.
EMAIL_C="scoor-e2e-c-$STAMP@gmail.com"
UID_C="$(seed_user "$EMAIL_C")"
TOKEN_C="$(signin "$EMAIL_C" | jqv access_token)"
if [ -z "$UID_C" ] || [ -z "$TOKEN_C" ]; then
  bad "C 계정 준비 실패 — Edge Function 검증 건너뜀"
else
  rest POST "scores?on_conflict=user_id,day" "$TOKEN_C" \
    "[{\"user_id\":\"$UID_C\",\"day\":\"2026-07-20\",\"value\":55,\"client_updated_at\":\"2026-07-20T10:00:00Z\"}]" >/dev/null
  check 1 "$(rest GET "scores?select=day" "$TOKEN_C" | count)" "C가 삭제 전 점수를 보유"

  # 세션 없는 호출이 통하면 남의 계정을 지울 수 있는 구멍이 된다.
  NOAUTH="$(curl -sS -m 30 -o /dev/null -w "%{http_code}" -X POST \
    "$BASE/functions/v1/account-delete" -H "apikey: $KEY")"
  check 401 "$NOAUTH" "세션 없는 삭제 요청은 401"

  DEL="$(curl -sS -m 30 -X POST "$BASE/functions/v1/account-delete" \
    -H "apikey: $KEY" -H "Authorization: Bearer $TOKEN_C")"
  echo "$DEL" | grep -q '"deleted":true' \
    && ok "C가 자기 계정 삭제 성공 (Edge Function)" \
    || bad "삭제 응답이 예상과 다름: $(echo "$DEL" | head -c 160)"

  GONE="$(supabase db query --linked \
    "select count(*) as n from auth.users where id = '$UID_C'" 2>/dev/null \
    | python3 -c "import sys,json,re;m=re.search(r'\{.*\}',sys.stdin.read(),re.S);d=json.loads(m.group(0)) if m else {};r=d.get('result') or d.get('rows') or [];print(r[0]['n'] if r else -1)")"
  check 0 "$GONE" "auth.users에서 C가 사라짐"

  LEFT_C="$(supabase db query --linked \
    "select count(*) as n from public.scores where user_id = '$UID_C'" 2>/dev/null \
    | python3 -c "import sys,json,re;m=re.search(r'\{.*\}',sys.stdin.read(),re.S);d=json.loads(m.group(0)) if m else {};r=d.get('result') or d.get('rows') or [];print(r[0]['n'] if r else -1)")"
  check 0 "$LEFT_C" "C의 점수까지 CASCADE 삭제됨"

  RETRY="$(curl -sS -m 30 -o /dev/null -w "%{http_code}" -X POST \
    "$BASE/functions/v1/account-delete" -H "apikey: $KEY" -H "Authorization: Bearer $TOKEN_C")"
  check 401 "$RETRY" "삭제된 계정의 토큰은 더 이상 통하지 않음"
fi

echo "== 8. 정리: 테스트 계정 삭제 (CASCADE 동작 확인 겸) =="
supabase db query --linked \
  "delete from auth.users where email in ('$EMAIL_A','$EMAIL_B')" >/dev/null 2>&1
LEFT="$(supabase db query --linked \
  "select count(*) as n from public.scores where user_id in ('$UID_A','$UID_B')" 2>/dev/null \
  | python3 -c "import sys,json,re;m=re.search(r'\{.*\}',sys.stdin.read(),re.S);d=json.loads(m.group(0)) if m else {};r=d.get('result') or d.get('rows') or [];print(r[0]['n'] if r else -1)")"
check 0 "$LEFT" "계정 삭제 시 점수까지 CASCADE 삭제됨 (완전 삭제 정책)"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
