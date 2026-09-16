/**
 * Session guard for admin API routes.
 *
 * `proxy.ts` only matches page routes (`/`, `/admin/:path*`, `/login`) — API
 * routes are outside its matcher, so every handler that touches real data has to
 * check the session itself. Without this an unauthenticated POST to
 * /api/topics would publish a topic to every user of the app.
 */

import { NextResponse } from "next/server";
import { cookies, headers } from "next/headers";
import { adminAuthConfig } from "@/lib/server/env";
import { SESSION_COOKIE, verifySessionToken } from "@/lib/server/session";

type GuardResult =
  { ok: true; email: string } | { ok: false; response: NextResponse };

export async function requireAdmin(): Promise<GuardResult> {
  const config = adminAuthConfig();
  if (!config) {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "어드민 인증이 설정되지 않았습니다." },
        { status: 503 },
      ),
    };
  }

  const cookieStore = await cookies();
  const payload = await verifySessionToken(
    cookieStore.get(SESSION_COOKIE)?.value,
    config.sessionSecret,
  );
  if (!payload || payload.email !== config.email) {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "로그인이 필요합니다." },
        { status: 401 },
      ),
    };
  }

  const h = await headers();
  const origin = h.get("origin");
  if (
    h.get("sec-fetch-site") === "cross-site" ||
    (origin && !isSameHost(origin, h.get("host")))
  ) {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "허용되지 않은 요청 출처입니다." },
        { status: 403 },
      ),
    };
  }
  return { ok: true, email: payload.email };
}

function isSameHost(origin: string, host: string | null) {
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}
