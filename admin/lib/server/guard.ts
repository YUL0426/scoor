/**
 * Session guard for admin API routes.
 *
 * `proxy.ts` only matches page routes (`/`, `/admin/:path*`, `/login`) — API
 * routes are outside its matcher, so every handler that touches real data has to
 * check the session itself. Without this an unauthenticated POST to
 * /api/topics would publish a topic to every user of the app.
 */

import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { adminAuthConfig } from "@/lib/server/env";
import { SESSION_COOKIE, verifySessionToken } from "@/lib/server/session";

type GuardResult =
  | { ok: true; email: string }
  | { ok: false; response: NextResponse };

export async function requireAdmin(): Promise<GuardResult> {
  const config = adminAuthConfig();
  if (!config) {
    return {
      ok: false,
      response: NextResponse.json({ error: "Admin auth is not configured." }, { status: 503 }),
    };
  }

  const cookieStore = await cookies();
  const payload = await verifySessionToken(
    cookieStore.get(SESSION_COOKIE)?.value,
    config.sessionSecret
  );
  if (!payload) {
    return {
      ok: false,
      response: NextResponse.json({ error: "Not authenticated." }, { status: 401 }),
    };
  }

  return { ok: true, email: payload.email };
}
