/**
 * Client-side auth API wrapper (P0-8).
 *
 * Credentials are verified server-side (/api/auth/login) against environment
 * variables, and the session lives in an httpOnly cookie signed with
 * ADMIN_SESSION_SECRET — nothing secret ships in this bundle, and nothing is
 * kept in localStorage. Route protection is enforced server-side in proxy.ts.
 */

import type { AdminUser } from "@/types";

export class AuthConfigError extends Error {
  constructor() {
    super("이 환경에는 어드민 인증이 설정되어 있지 않습니다.");
    this.name = "AuthConfigError";
  }
}

/** Sign in. Returns the admin user, null on bad credentials. */
export async function signIn(
  email: string,
  password: string
): Promise<AdminUser | null> {
  const res = await fetch("/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (res.status === 401) return null;
  if (res.status === 503) throw new AuthConfigError();
  if (!res.ok) throw new Error(`Login failed (${res.status})`);
  const data = (await res.json()) as { user: AdminUser };
  return data.user;
}

/** Current session's user, or null when signed out. */
export async function fetchSessionUser(): Promise<AdminUser | null> {
  const res = await fetch("/api/auth/session", { cache: "no-store" });
  if (!res.ok) return null;
  const data = (await res.json()) as { user: AdminUser };
  return data.user;
}

export async function signOut(): Promise<void> {
  await fetch("/api/auth/logout", { method: "POST" });
}
