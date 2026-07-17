# Scoor Admin

Operations dashboard for Scoor (Next.js App Router). **Dashboard data is
currently mock/sample data** — only authentication is real.

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Configure auth (required — sign-in fails closed without it):

   ```bash
   cp .env.example .env.local
   # then fill in:
   #   ADMIN_EMAIL             — admin login email
   #   ADMIN_PASSWORD_SHA256   — printf '%s' 'password' | shasum -a 256 | cut -d' ' -f1
   #   ADMIN_SESSION_SECRET    — openssl rand -hex 32
   ```

3. Run:

   ```bash
   npm run dev
   ```

## Auth architecture

- Credentials are verified server-side in `app/api/auth/login/route.ts`
  against environment variables; no credentials exist in the client bundle.
- Sessions are HMAC-SHA256-signed tokens in an httpOnly cookie
  (`lib/server/session.ts`).
- `proxy.ts` enforces auth on `/`, `/admin/*`, and `/login` at the edge,
  so route protection does not depend on client JavaScript.
- The client (`lib/auth.ts`, `providers/auth-provider.tsx`) only calls the
  API routes; nothing is stored in localStorage.
