// account-delete — 계정 완전 삭제 (spec-13 §4.2, P0-4, App Store 5.1.1(v))
//
// 클라이언트가 직접 못 하는 두 가지를 대신한다:
//   1. auth.users 삭제 — service-role 키가 필요하고, 그 키는 앱 번들에 절대
//      들어갈 수 없다.
//   2. Apple refresh token revoke — Apple이 요구하는 절차이며 client_secret
//      (팀 키로 서명한 JWT)이 있어야 한다.
//
// 삭제 정책은 "완전 삭제"로 확정되어 있다 (spec-13 §15-5). auth.users 한 행을
// 지우면 profiles → scores / world_scores / blocks / reports 까지 CASCADE로
// 함께 사라진다.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/// Apple 토큰 폐기. 자격증명이 설정돼 있지 않으면 건너뛴다 — Apple 로그인을
/// 쓰지 않는 계정을 지우는 것까지 막을 이유는 없다.
async function revokeAppleToken(refreshToken: string | null): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  const clientSecret = Deno.env.get("APPLE_CLIENT_SECRET");
  if (!refreshToken || !clientId || !clientSecret) return;

  await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ message: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ message: "Missing Authorization header" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;

  // 호출자 신원은 반드시 토큰에서 얻는다. 본문의 user_id를 믿으면 남의 계정을
  // 지울 수 있는 구멍이 된다.
  const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await asCaller.auth.getUser();
  if (userError || !user) return json({ message: "Invalid session" }, 401);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Apple 폐기를 먼저 시도한다. 유저 행이 사라진 뒤에는 토큰을 읽을 수 없다.
  try {
    const { data: identities } = await admin
      .from("auth.identities")
      .select("provider, identity_data")
      .eq("user_id", user.id);
    const apple = identities?.find((i: { provider: string }) => i.provider === "apple");
    await revokeAppleToken(apple?.identity_data?.refresh_token ?? null);
  } catch (_) {
    // 폐기 실패가 삭제를 막지는 않는다 — 사용자의 삭제 요청이 우선이다.
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return json({ message: error.message }, 500);

  return json({ deleted: true });
});
