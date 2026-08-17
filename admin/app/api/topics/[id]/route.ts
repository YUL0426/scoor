/**
 * Publish / close a single topic.
 *
 * Status is the only mutable field on purpose: editing the title of a topic
 * people have already scored would change what their score meant. Closing keeps
 * it readable and stops new submissions (`topics_write` policy), which is the
 * right end-of-life for a match or an event that finished.
 */

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest, SupabaseRestError } from "@/lib/server/supabase";
import { TOPIC_STATUSES, type TopicStatus } from "@/types";

export async function PATCH(request: NextRequest, ctx: RouteContext<"/api/topics/[id]">) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) {
    return NextResponse.json({ error: "백엔드가 설정되지 않았습니다. admin/.env.local의 SUPABASE_URL·SUPABASE_SERVICE_ROLE_KEY를 확인해주세요." }, { status: 503 });
  }

  const { id } = await ctx.params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return NextResponse.json({ error: "토픽 id가 올바르지 않습니다." }, { status: 400 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "요청 본문 형식이 올바르지 않습니다." }, { status: 400 });
  }

  const status = (body as { status?: unknown })?.status;
  if (typeof status !== "string" || !TOPIC_STATUSES.includes(status as TopicStatus)) {
    return NextResponse.json(
      { error: `Status must be one of: ${TOPIC_STATUSES.join(", ")}.` },
      { status: 400 }
    );
  }

  try {
    const updated = await supabaseRest<{ id: string; status: TopicStatus }[]>(config, "topics", {
      method: "PATCH",
      query: `id=eq.${id}`,
      body: { status },
      returning: true,
    });
    if (!updated || updated.length === 0) {
      return NextResponse.json({ error: "토픽을 찾을 수 없습니다." }, { status: 404 });
    }
    return NextResponse.json({ topic: updated[0] });
  } catch (error) {
    if (error instanceof SupabaseRestError) {
      const code = error.status >= 400 && error.status < 500 ? 400 : 502;
      return NextResponse.json({ error: error.message }, { status: code });
    }
    return NextResponse.json({ error: "백엔드에 연결하지 못했습니다." }, { status: 502 });
  }
}
