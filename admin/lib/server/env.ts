/**
 * Admin auth configuration — server-only, sourced from environment variables.
 * See .env.example. When any variable is missing, auth fails closed (503):
 * nobody can sign in, and nothing secret ships in the client bundle.
 */

export interface AdminAuthConfig {
  email: string;
  /** SHA-256 hex digest of the admin password. */
  passwordSha256: string;
  sessionSecret: string;
}

export function adminAuthConfig(): AdminAuthConfig | null {
  const email = process.env.ADMIN_EMAIL;
  const passwordSha256 = process.env.ADMIN_PASSWORD_SHA256;
  const sessionSecret = process.env.ADMIN_SESSION_SECRET;
  if (!email || !passwordSha256 || !sessionSecret) return null;
  return { email: email.toLowerCase(), passwordSha256: passwordSha256.toLowerCase(), sessionSecret };
}
