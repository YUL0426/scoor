import { checkOrigin } from "@/lib/server/origin";
import { NextResponse } from "next/server";
import { SESSION_COOKIE } from "@/lib/server/session";

export async function POST(request: Request) {
  const denied = checkOrigin(request);
  if (denied) return denied;
  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
  return response;
}
