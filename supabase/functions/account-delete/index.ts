// account-delete — 계정 완전 삭제 (spec-13 §4.2, P0-4, App Store 5.1.1(v))
//
// 클라이언트가 직접 못 하는 두 가지를 대신한다:
//   1. auth.users 삭제 — service-role 키가 필요하고, 그 키는 앱 번들에 절대
//      들어갈 수 없다.
//   2. Apple 토큰 revoke — Apple이 요구하는 절차이며 client_secret(팀 키로 서명한
//      ES256 JWT)이 있어야 한다.
//
// 삭제 정책은 "완전 삭제"로 확정되어 있다 (spec-13 §15-5). auth.users 한 행을
// 지우면 profiles → scores / world_scores / blocks / reports 까지 CASCADE로
// 함께 사라진다.
//
// ---------------------------------------------------------------------------
// Apple 폐기가 왜 authorization code를 받는가
// ---------------------------------------------------------------------------
// 이 함수는 원래 `identities.identity_data.refresh_token`을 읽어 폐기하려 했다.
// 그런데 앱은 네이티브 `signInWithIdToken` 그랜트를 쓴다 — Supabase는 id token만
// 검증할 뿐 Apple과 코드 교환을 하지 않으므로 refresh token을 애초에 받지 않는다.
// 그래서 저 경로는 항상 null을 읽었고, APPLE_CLIENT_SECRET을 넣어도 폐기는
// 일어나지 않았다. 심사에서 통과하더라도 Apple 계정 설정에는 앱이 계속 남는다.
//
// 이제 앱이 삭제 시점에 `ASAuthorization`으로 **새 authorization code**를 받아
// 보내고(코드는 1회용·5분 만료라 로그인 때 받은 것을 보관해 봐야 못 쓴다),
// 함수가 그것을 refresh token으로 교환한 뒤 폐기한다. 옛 경로는 폴백으로 남겨
// 둔다 — 나중에 웹 OAuth 그랜트를 쓰게 되면 그쪽에는 값이 들어 있다.

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

// ---------------------------------------------------------------------------
// Apple client secret (ES256 JWT)
// ---------------------------------------------------------------------------

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function encodeJSON(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

async function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  // 시크릿 저장소를 거치면서 개행이 "\n" 두 글자로 변하는 일이 흔하다.
  const normalized = pem.replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

/// Apple client secret. 미리 만들어 둔 JWT(APPLE_CLIENT_SECRET)를 넣어도 되지만,
/// 그것은 최대 6개월이면 만료되고 만료 사실이 조용히 드러난다(폐기가 실패해도
/// 삭제는 성공하므로). 팀 키(.p8)를 넣어 두면 매 호출마다 새로 서명한다.
async function appleClientSecret(clientId: string): Promise<string | null> {
  const preset = Deno.env.get("APPLE_CLIENT_SECRET");
  if (preset) return preset;

  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamId || !keyId || !privateKey) return null;

  const now = Math.floor(Date.now() / 1000);
  const signingInput = [
    encodeJSON({ alg: "ES256", kid: keyId }),
    encodeJSON({
      iss: teamId,
      iat: now,
      exp: now + 300,
      aud: "https://appleid.apple.com",
      sub: clientId,
    }),
  ].join(".");

  const key = await importApplePrivateKey(privateKey);
  // WebCrypto의 ECDSA 서명은 raw r||s (64바이트)로 나오는데, JWS ES256이
  // 요구하는 형식이 바로 그것이다 — DER 재인코딩이 필요 없다.
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput)),
  );
  return `${signingInput}.${base64url(signature)}`;
}

async function exchangeAuthorizationCode(
  code: string,
  clientId: string,
  clientSecret: string,
): Promise<string | null> {
  const res = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: "authorization_code",
    }),
  });
  if (!res.ok) {
    console.error("apple token exchange failed", res.status, await res.text());
    return null;
  }
  const payload = await res.json();
  return (payload.refresh_token as string | undefined) ?? null;
}

/// Apple 토큰 폐기. 자격증명이 없으면 건너뛴다 — Apple 로그인을 쓰지 않는 계정을
/// 지우는 것까지 막을 이유는 없다. 성공 여부를 돌려주되 삭제를 좌우하지는 않는다.
async function revokeApple(
  authorizationCode: string | null,
  storedRefreshToken: string | null,
): Promise<boolean> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!clientId) return false;
  if (!authorizationCode && !storedRefreshToken) return false;

  const clientSecret = await appleClientSecret(clientId);
  if (!clientSecret) return false;

  let token = storedRefreshToken;
  if (authorizationCode) {
    const exchanged = await exchangeAuthorizationCode(authorizationCode, clientId, clientSecret);
    if (exchanged) {
      token = exchanged;
    } else if (!storedRefreshToken) {
      return false;
    }
  }
  if (!token) return false;

  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!res.ok) console.error("apple revoke failed", res.status, await res.text());
  return res.ok;
}

// ---------------------------------------------------------------------------

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

  let authorizationCode: string | null = null;
  try {
    const body = await req.json();
    const raw = body?.apple_authorization_code;
    if (typeof raw === "string" && raw.length > 0) authorizationCode = raw;
  } catch (_) {
    // 본문 없음 = Apple 계정이 아니거나 사용자가 재인증을 거부한 경우.
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // 폐기를 먼저 시도한다. 유저 행이 사라진 뒤에는 폴백 토큰을 읽을 수 없다.
  // auth 스키마는 PostgREST로 노출되지 않으므로 Admin API로 읽는다.
  let appleRevoked = false;
  try {
    let storedRefreshToken: string | null = null;
    const { data } = await admin.auth.admin.getUserById(user.id);
    const apple = (data?.user?.identities ?? []).find((i) => i.provider === "apple");
    if (apple) {
      const identityData = apple.identity_data as Record<string, unknown> | undefined;
      storedRefreshToken = (identityData?.refresh_token as string) ?? null;
      appleRevoked = await revokeApple(authorizationCode, storedRefreshToken);
    }
  } catch (err) {
    // 폐기 실패가 삭제를 막지는 않는다 — 사용자의 삭제 요청이 우선이다.
    console.error("apple revocation skipped", err);
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return json({ message: error.message }, 500);

  return json({ deleted: true, apple_revoked: appleRevoked });
});
