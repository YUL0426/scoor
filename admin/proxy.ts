/**
 * Server-side route protection for the admin panel (P0-8).
 *
 * Every /admin route requires a valid, HMAC-signed session cookie; anything
 * else bounces to /login before rendering. An authenticated user visiting
 * /login is sent to /admin. Runs at the edge, so protection holds even with
 * JavaScript disabled — unlike the previous localStorage-only client check.
 *
 * (Next 16: the `middleware` file convention is deprecated → `proxy.ts`.)
 */

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { SESSION_COOKIE, verifySessionToken } from "@/lib/server/session";

export async function proxy(request: NextRequest) {
  const secret = process.env.ADMIN_SESSION_SECRET;
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  // Fail closed: without a configured secret no session can ever verify.
  const session = secret ? await verifySessionToken(token, secret) : null;

  const { pathname } = request.nextUrl;
  const isLogin = pathname === "/login";

  if (!session && !isLogin) {
    const url = new URL("/login", request.url);
    return NextResponse.redirect(url);
  }
  if (session && isLogin) {
    return NextResponse.redirect(new URL("/admin", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/", "/admin/:path*", "/login"],
};
