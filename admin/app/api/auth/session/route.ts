import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { adminAuthConfig } from "@/lib/server/env";
import { SESSION_COOKIE, verifySessionToken } from "@/lib/server/session";
import type { AdminUser } from "@/types";

export async function GET() {
  const config = adminAuthConfig();
  if (!config) {
    return NextResponse.json({ error: "Admin auth is not configured." }, { status: 503 });
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  const payload = await verifySessionToken(token, config.sessionSecret);
  if (!payload) {
    return NextResponse.json({ error: "Not authenticated." }, { status: 401 });
  }

  const user: AdminUser = {
    id: "admin_01",
    email: payload.email,
    name: "Admin",
    role: "super_admin",
    avatarUrl: null,
    lastLoginAt: new Date().toISOString(),
  };
  return NextResponse.json({ user });
}
