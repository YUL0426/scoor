import { NextResponse } from "next/server";
import { adminAuthConfig } from "@/lib/server/env";
import {
  SESSION_COOKIE,
  SESSION_TTL_SECONDS,
  createSessionToken,
  sha256Hex,
  timingSafeEqual,
} from "@/lib/server/session";
import type { AdminUser } from "@/types";

export async function POST(request: Request) {
  const config = adminAuthConfig();
  if (!config) {
    return NextResponse.json(
      { error: "Admin auth is not configured on this deployment." },
      { status: 503 }
    );
  }

  let email = "";
  let password = "";
  try {
    const body = (await request.json()) as { email?: string; password?: string };
    email = (body.email ?? "").trim().toLowerCase();
    password = body.password ?? "";
  } catch {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }

  const passwordHash = await sha256Hex(password);
  const emailOk = timingSafeEqual(email, config.email);
  const passwordOk = timingSafeEqual(passwordHash, config.passwordSha256);
  if (!emailOk || !passwordOk) {
    return NextResponse.json({ error: "Invalid credentials." }, { status: 401 });
  }

  const user: AdminUser = {
    id: "admin_01",
    email: config.email,
    name: "Admin",
    role: "super_admin",
    avatarUrl: null,
    lastLoginAt: new Date().toISOString(),
  };

  const token = await createSessionToken(config.email, config.sessionSecret);
  const response = NextResponse.json({ user });
  response.cookies.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
  });
  return response;
}
