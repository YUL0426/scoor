import type { AdminUser, AuthSession } from "@/types";

const MOCK_ADMIN: AdminUser = {
  id: "admin_01",
  email: "admin@scoor.app",
  name: "Admin",
  role: "super_admin",
  avatarUrl: null,
  lastLoginAt: new Date().toISOString(),
};

const MOCK_CREDENTIALS = {
  email: "admin@scoor.app",
  password: "scoor2026",
};

const SESSION_KEY = "scoor_admin_session";

export async function signIn(
  email: string,
  password: string
): Promise<AuthSession | null> {
  await new Promise((r) => setTimeout(r, 600));

  if (
    email.toLowerCase() !== MOCK_CREDENTIALS.email ||
    password !== MOCK_CREDENTIALS.password
  ) {
    return null;
  }

  const session: AuthSession = {
    user: MOCK_ADMIN,
    token: `mock_token_${Date.now()}`,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  };

  if (typeof window !== "undefined") {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  }

  return session;
}

export function getSession(): AuthSession | null {
  if (typeof window === "undefined") return null;

  const raw = localStorage.getItem(SESSION_KEY);
  if (!raw) return null;

  try {
    const session = JSON.parse(raw) as AuthSession;
    if (new Date(session.expiresAt) < new Date()) {
      localStorage.removeItem(SESSION_KEY);
      return null;
    }
    return session;
  } catch {
    return null;
  }
}

export function signOut(): void {
  if (typeof window !== "undefined") {
    localStorage.removeItem(SESSION_KEY);
  }
}

export function isAuthenticated(): boolean {
  return getSession() !== null;
}
