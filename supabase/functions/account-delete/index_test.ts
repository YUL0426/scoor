import { createHandler } from "./handler.ts";
const NONCE = "a".repeat(64);
function workerRequest(nonce = NONCE) {
  return new Request("https://test.invalid/account-delete", { method: "POST", headers: { "x-scoor-retry-nonce": nonce } });
}

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function fixture(options: { apple?: boolean; authorized?: boolean; queueFails?: boolean; lookupFails?: boolean; queueReadError?: string; queueStateFails?: boolean } = {}) {
  const queue: Array<{ id: string; refresh_token: string | null; status: string; attempts: number; lease_id?: string }> = [];
  let nonceConsumed = false;
  let deleted = false;
  let authCalls = 0;
  const tables: string[] = [];
  const user = { id: "test-user", identities: options.apple === false ? [] : [{ provider: "apple", identity_data: {} }] };
  const client = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      if (name === "claim_apple_revocation_retries") {
        if (options.queueReadError) return { data: null, error: new Error(options.queueReadError) };
        if (args.p_nonce !== NONCE || nonceConsumed) return { data: { authorized: false, items: [] }, error: null };
        nonceConsumed = true;
        const items = queue.filter(row => row.status === "retry_pending").slice(0, 10);
        for (const row of items) { row.status = "retrying"; row.lease_id = `lease-${row.id}`; row.attempts++; }
        return { data: { authorized: true, items: items.map(row => ({ ...row })) }, error: null };
      }
      assert(name === "finish_apple_revocation_retry");
      const index = queue.findIndex(row => row.id === args.p_id && row.lease_id === args.p_lease && row.status === "retrying");
      if (index < 0) return { data: false, error: null };
      if (args.p_success) queue.splice(index, 1);
      else { queue[index].status = "retry_pending"; delete queue[index].lease_id; }
      return { data: true, error: null };
    },
    auth: {
      getUser: async () => { authCalls++; return { data: { user: options.authorized === false ? null : user }, error: null }; },
      admin: {
        getUserById: async () => { authCalls++; return { data: { user }, error: options.lookupFails ? new Error("offline") : null }; },
        deleteUser: async () => { deleted = true; return { error: null }; },
      },
    },
    from: (table: string) => {
      tables.push(table);
      let action = "read", id: string, values: Record<string, unknown> = {};
      const filters: Record<string, string> = {};
      const finish = () => {
        if (action === "update" && options.queueStateFails) return { error: new Error("state write failed"), data: [] };
        const matches = (row: typeof queue[number]) => Object.entries(filters).every(([column, value]) => row[column as keyof typeof row] === value);
        if (action === "delete") { const index = queue.findIndex(matches); if (index >= 0) queue.splice(index, 1); }
        if (action === "update") Object.assign(queue.find(matches) ?? {}, values);
        return { error: action === "read" && options.queueReadError ? new Error(options.queueReadError) : null,
          data: queue.filter(row => Object.entries(filters).every(([column, value]) => row[column as keyof typeof row] === value)) };
      };
      const chain = {
        insert(value: Record<string, unknown>) { action = "insert"; values = value; return chain; },
        select(_value?: string) { return chain; },
        eq(column: string, value: string) { filters[column] = value; if (column === "id") id = value; return chain; },
        order(_value: string) { return chain; },
        limit(value: number) { const result = finish(); return Promise.resolve({ ...result, data: result.data.slice(0, value) }); },
        delete() { action = "delete"; return chain; },
        update(value: Record<string, unknown>) { action = "update"; values = value; return chain; },
        single() {
          if (options.queueFails) return Promise.resolve({ data: null, error: new Error("queue unavailable") });
          const row = { id: `queue-${queue.length}`, refresh_token: values.refresh_token as string | null, status: values.status as string, attempts: 0 };
          queue.push(row); return Promise.resolve({ data: row, error: null });
        },
        then(resolve: (value: ReturnType<typeof finish>) => unknown) { return Promise.resolve(resolve(finish())); },
      };
      return chain;
    },
  };
  const factory = (() => client) as unknown as NonNullable<Parameters<typeof createHandler>[0]>;
  return { handler: createHandler(factory), queue, deleted: () => deleted, authCalls: () => authCalls, tables };
}
function request(token = "user-token") {
  return new Request("https://test.invalid/account-delete", { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: JSON.stringify({ apple_authorization_code: "fresh-code" }) });
}
async function withApple(callback: () => Promise<void>) {
  const keys = { SUPABASE_URL: "https://test.invalid", SUPABASE_ANON_KEY: "anon-test", SUPABASE_SERVICE_ROLE_KEY: "service-test", SUPABASE_SECRET_KEYS: JSON.stringify({ default: "sb_secret_test_only" }), APPLE_CLIENT_ID: "test.app", APPLE_CLIENT_SECRET: "test-secret" };
  const saved = Object.fromEntries(Object.keys(keys).map(key => [key, Deno.env.get(key)]));
  const fetch = globalThis.fetch;
  for (const [key, value] of Object.entries(keys)) Deno.env.set(key, value);
  try { await callback(); } finally {
    globalThis.fetch = fetch;
    for (const [key, value] of Object.entries(saved)) { if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value); }
  }
}
Deno.test("failed Apple revoke retains token before deleting account", () => withApple(async () => {
  const f = fixture();
  globalThis.fetch = async (input) => {
    if (String(input).endsWith("/token")) return Response.json({ refresh_token: "retry-token" });
    assert(f.queue[0]?.refresh_token === "retry-token", "Token must persist before revoke");
    return new Response(null, { status: 503 });
  };
  const response = await f.handler(request());
  assert(response.status === 200 && f.deleted());
  assert((await response.json()).apple_revocation_pending === true);
  assert(f.queue.length === 1 && f.queue[0].status === "retry_pending");
}));
Deno.test("one-use worker retries and removes successful revocation", () => withApple(async () => {
  const f = fixture(); f.queue.push({ id: "old", refresh_token: "retry-token", status: "retry_pending", attempts: 1 });
  globalThis.fetch = async () => new Response(null, { status: 200 });
  const response = await f.handler(workerRequest());
  assert((await response.json()).completed === 1 && f.queue.length === 0 && !f.deleted());
}));
Deno.test("unverified caller cannot delete or retry tokens", () => withApple(async () => {
  const f = fixture({ authorized: false });
  assert((await f.handler(request())).status === 401 && !f.deleted());
}));
Deno.test("scheduled worker accepts a valid one-use nonce", () => withApple(async () => {
  const f = fixture(); f.queue.push({ id: "old", refresh_token: "retry-token", status: "retry_pending", attempts: 1 });
  globalThis.fetch = async () => new Response(null, { status: 200 });
  const response = await f.handler(workerRequest());
  assert(response.status === 200 && (await response.json()).completed === 1 && !f.deleted());
}));
Deno.test("public or unknown API keys cannot trigger a worker", () => withApple(async () => {
  const f = fixture();
  for (const key of ["anon-test", "sb_publishable_test", "sb_secret_unknown", "sb_secret_test_only", ""]) {
    const response = await f.handler(new Request("https://test.invalid/account-delete", { method: "POST", headers: { apikey: key } }));
    assert(response.status === 401 && !f.deleted());
  }
}));

Deno.test("initial revocation is not eligible for a worker until a failure is recorded", () => withApple(async () => {
  const f = fixture();
  globalThis.fetch = async (input) => {
    if (String(input).endsWith("/token")) return Response.json({ refresh_token: "first-token" });
    assert(f.queue[0].status === "in_progress");
    const worker = await f.handler(workerRequest());
    assert((await worker.json()).completed === 0);
    return new Response(null, { status: 503 });
  };
  const response = await f.handler(request());
  assert(response.status === 200 && f.queue[0].status === "retry_pending");
}));

Deno.test("replayed, unknown and malformed nonces never enter user deletion", () => withApple(async () => {
  const f = fixture();
  assert((await f.handler(workerRequest())).status === 200);
  for (const nonce of [NONCE, "b".repeat(64), "", "invalid"]) {
    const response = await f.handler(new Request("https://test.invalid/account-delete", {
      method: "POST", headers: { "x-scoor-retry-nonce": nonce, Authorization: "Bearer user-token" },
    }));
    assert(response.status === 403 && !f.deleted() && f.authCalls() === 0);
  }
}));

Deno.test("successful first revocation leaves no retry token", () => withApple(async () => {
  const f = fixture();
  globalThis.fetch = async input => String(input).endsWith("/token")
    ? Response.json({ refresh_token: "first-token" }) : new Response(null, { status: 200 });
  const response = await f.handler(request());
  assert((await response.json()).apple_revoked === true && f.queue.length === 0 && f.deleted());
}));

Deno.test("failure to persist the retry state preserves the account", () => withApple(async () => {
  const f = fixture({ queueStateFails: true });
  globalThis.fetch = async input => String(input).endsWith("/token")
    ? Response.json({ refresh_token: "first-token" }) : new Response(null, { status: 503 });
  const response = await f.handler(request());
  assert(response.status === 503 && !f.deleted() && f.queue[0].status === "in_progress");
}));
Deno.test("exchange outage allows deletion and reports Apple followup", () => withApple(async () => {
  const f = fixture(); globalThis.fetch = async () => { throw new Error("offline"); };
  const response = await f.handler(request());
  assert(response.status === 200 && f.deleted());
  assert((await response.json()).apple_revoked === false);
}));
Deno.test("token storage failure preserves account for safe retry", () => withApple(async () => {
  const f = fixture({ queueFails: true });
  globalThis.fetch = async () => Response.json({ refresh_token: "retry-token" });
  assert((await f.handler(request())).status === 503 && !f.deleted());
}));
Deno.test("email account deletion needs no Apple configuration", () => withApple(async () => {
  const f = fixture({ apple: false });
  globalThis.fetch = async () => { throw new Error("Unexpected Apple request"); };
  assert((await f.handler(request())).status === 200 && f.deleted() && f.queue.length === 0);
}));
Deno.test("provider lookup failure preserves account for retry", () => withApple(async () => {
  const f = fixture({ lookupFails: true });
  assert((await f.handler(request())).status === 503 && !f.deleted());
}));

Deno.test("worker ignores caller payload, excludes needs_authorization, and processes at most ten pending tokens", () => withApple(async () => {
  const f = fixture();
  f.queue.push({ id: "needs-user", refresh_token: "must-not-revoke", status: "needs_authorization", attempts: 0 });
  for (let i = 0; i < 11; i++) f.queue.push({ id: `pending-${i}`, refresh_token: `pending-token-${i}`, status: "retry_pending", attempts: 1 });
  const tokens: string[] = [];
  globalThis.fetch = async (input, init) => {
    assert(String(input) === "https://appleid.apple.com/auth/revoke", "Worker must not exchange an authorization code");
    tokens.push(new URLSearchParams(String(init?.body)).get("token")!);
    return new Response(null, { status: 200 });
  };
  const response = await f.handler(new Request("https://test.invalid/account-delete", {
    method: "POST", headers: { "x-scoor-retry-nonce": NONCE, Authorization: "Bearer user-token", "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: "another-user", apple_authorization_code: "must-not-exchange", action: "delete" }),
  }));
  assert(JSON.stringify(await response.json()) === '{"completed":10}');
  assert(tokens.length === 10 && tokens.every(token => token.startsWith("pending-token-")));
  assert(f.queue.length === 2 && f.queue.some(row => row.id === "needs-user"));
  assert(f.authCalls() === 0 && !f.deleted(), "Worker must return before account operations");
  assert(f.tables.every(table => table === "apple_revocation_queue"));
}));

Deno.test("worker responses and application logs omit keys and Apple tokens even when an upstream error contains them", () => withApple(async () => {
  const f = fixture();
  f.queue.push({ id: "retry-row", refresh_token: "apple-token-canary", status: "retry_pending", attempts: 1 });
  const logs: string[] = [];
  const savedError = console.error;
  console.error = (...args: unknown[]) => logs.push(args.map(String).join(" "));
  try {
    globalThis.fetch = async () => { throw new Error("sb_secret_test_only apple-token-canary test-secret"); };
    const response = await f.handler(workerRequest());
    const body = await response.text();
    assert(response.status === 200 && body === '{"completed":0}');
    const visible = body + logs.join(" ");
    for (const secret of ["sb_secret_test_only", "apple-token-canary", "test-secret"]) assert(!visible.includes(secret));
    assert(f.queue.length === 1 && f.authCalls() === 0 && !f.deleted());
  } finally { console.error = savedError; }
}));

Deno.test("worker queue errors return a fixed response without exposing the upstream error or entering account deletion", () => withApple(async () => {
  const f = fixture({ queueReadError: "sb_secret_test_only sensitive-upstream-detail" });
  const response = await f.handler(workerRequest());
  assert(response.status === 503);
  assert(await response.text() === '{"message":"Revocation queue unavailable"}');
  assert(f.authCalls() === 0 && !f.deleted());
}));
