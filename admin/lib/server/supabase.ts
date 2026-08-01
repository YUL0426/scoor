/**
 * Service-role access to the Scoor backend — server-only.
 *
 * The key here bypasses every RLS policy, so it must never appear in a client
 * bundle: no `NEXT_PUBLIC_` prefix, and this module is only ever imported from
 * route handlers. Missing configuration fails closed (the caller returns 503)
 * rather than falling back to mock data, because silently showing fake topics in
 * an ops tool would get real ones published to nobody.
 *
 * Deliberately fetch-based rather than @supabase/supabase-js, matching the iOS
 * client's hand-rolled PostgREST layer (spec-13 §2.2).
 */

export interface SupabaseAdminConfig {
  url: string;
  serviceRoleKey: string;
}

export function supabaseAdminConfig(): SupabaseAdminConfig | null {
  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) return null;
  return { url: url.replace(/\/+$/, ""), serviceRoleKey };
}

export class SupabaseRestError extends Error {
  constructor(
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

interface RestOptions {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  /** PostgREST query string, without the leading `?`. */
  query?: string;
  body?: unknown;
  /** Ask PostgREST to return the affected rows. */
  returning?: boolean;
}

/**
 * Call PostgREST with the service role. Returns parsed JSON, or null when the
 * response carries no body (`return=minimal`).
 */
export async function supabaseRest<T>(
  config: SupabaseAdminConfig,
  table: string,
  { method = "GET", query, body, returning = false }: RestOptions = {}
): Promise<T | null> {
  const url = `${config.url}/rest/v1/${table}${query ? `?${query}` : ""}`;

  const headers: Record<string, string> = {
    apikey: config.serviceRoleKey,
    Authorization: `Bearer ${config.serviceRoleKey}`,
    Prefer: returning ? "return=representation" : "return=minimal",
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    // Ops data must never be served stale from a build-time cache.
    cache: "no-store",
  });

  const text = await response.text();
  if (!response.ok) {
    let message = text;
    try {
      const parsed = JSON.parse(text) as { message?: string; hint?: string };
      message = parsed.message ?? text;
    } catch {
      // Non-JSON error body — use it as-is.
    }
    throw new SupabaseRestError(message || `HTTP ${response.status}`, response.status);
  }

  if (!text) return null;
  return JSON.parse(text) as T;
}
