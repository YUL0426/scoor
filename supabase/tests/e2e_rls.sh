#!/usr/bin/env bash
# 실서버 RLS / 동기화 계약 검증 (spec-13 Phase 1).
#
# 앱이 실제로 호출하는 것과 같은 PostgREST/GoTrue 엔드포인트를 그대로 두드린다 —
# 로컬 Postgres 검증이 스키마 논리를 증명한다면, 이 스크립트는 배포된 프로젝트에
# RLS가 실제로 켜져 있는지를 증명한다.
#
# 사전 조건 (둘 다 대시보드 설정):
#   1. supabase db push 로 마이그레이션이 적용되어 있을 것
#   2. Authentication → Sign In/Providers → Email → "Confirm email" OFF
#      (켜져 있으면 가입 직후 세션이 없어 로그인 왕복을 검증할 수 없다)
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

echo "== 0. 계정 생성 =="
RA="$(signup "$EMAIL_A")"; TOKEN_A="$(echo "$RA" | jqv access_token)"
RB="$(signup "$EMAIL_B")"; TOKEN_B="$(echo "$RB" | jqv access_token)"
if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then
  echo "  가입 응답에 세션이 없습니다. 'Confirm email'이 켜져 있는지 확인하세요."
  echo "  A: $(echo "$RA" | head -c 200)"
  exit 1
fi
UID_A="$(echo "$RA" | python3 -c "import sys,json;print(json.load(sys.stdin)['user']['id'])")"
UID_B="$(echo "$RB" | python3 -c "import sys,json;print(json.load(sys.stdin)['user']['id'])")"
ok "A/B 세션 발급 (A=$UID_A)"

echo "== 1. 가입 트리거: 프로필 자동 생성 =="
check 1 "$(rest GET "profiles?id=eq.$UID_A&select=id,username" "$TOKEN_A" | count)" "A의 프로필이 생성됨"

echo "== 2. scores RLS: 소유자만 =="
rest POST "scores" "$TOKEN_A" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-19\",\"value\":72,\"reason\":\"E2E\",\"client_updated_at\":\"2026-07-19T10:00:00Z\"}]" >/dev/null
check 1 "$(rest GET "scores?select=day,value" "$TOKEN_A" | count)" "A가 자기 점수를 읽음"
check 0 "$(rest GET "scores?select=day,value" "$TOKEN_B" | count)" "B는 A의 점수를 볼 수 없음"

RESP="$(rest POST "scores" "$TOKEN_B" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-18\",\"value\":1,\"client_updated_at\":\"2026-07-19T10:00:00Z\"}]")"
echo "$RESP" | grep -q "42501\|violates row-level security" \
  && ok "B가 A의 계정에 쓰기 시도 → 차단됨" \
  || bad "B가 A의 계정에 썼습니다: $(echo "$RESP" | head -c 120)"

echo "== 3. Last-write-wins 트리거 =="
rest POST "scores" "$TOKEN_A" \
  "[{\"user_id\":\"$UID_A\",\"day\":\"2026-07-19\",\"value\":10,\"client_updated_at\":\"2026-07-19T09:00:00Z\"}]" >/dev/null
V="$(rest GET "scores?day=eq.2026-07-19&select=value" "$TOKEN_A" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['value'])" 2>/dev/null)"
check 72 "$V" "오래된 쓰기(09:00)는 무시됨"

rest POST "scores" "$TOKEN_A" \
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
check 0 "$(rest GET "reports?select=id" "$TOKEN_B" | count)" "신고자가 신고 내역을 되읽을 수 없음"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
echo "정리: 아래 계정은 테스트 잔여물입니다 — 대시보드 Authentication에서 삭제하세요."
echo "  $EMAIL_A"
echo "  $EMAIL_B"
[ "$FAIL" -eq 0 ]
