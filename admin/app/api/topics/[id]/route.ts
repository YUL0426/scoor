/** Update publication state or editorial translations; canonical questions stay immutable. */
import { parseTopicTranslations, type TopicTranslations } from "@/lib/topic-translations";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import {
  supabaseAdminConfig,
  supabaseRest,
  SupabaseRestError,
} from "@/lib/server/supabase";
import { TOPIC_STATUSES, type TopicStatus } from "@/types";

export async function PATCH(
  request: NextRequest,
  ctx: RouteContext<"/api/topics/[id]">,
) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) {
    return NextResponse.json(
      {
        error:
          "백엔드가 설정되지 않았습니다. admin/.env.local의 SUPABASE_URL·SUPABASE_SERVICE_ROLE_KEY를 확인해주세요.",
      },
      { status: 503 },
    );
  }

  const { id } = await ctx.params;
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
  ) {
    return NextResponse.json(
      { error: "토픽 id가 올바르지 않습니다." },
      { status: 400 },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "요청 본문 형식이 올바르지 않습니다." },
      { status: 400 },
    );
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json({ error: "요청 본문은 객체여야 합니다." }, { status: 400 });
  }
  const input = body as Record<string, unknown>;
  if (!Object.keys(input).length || Object.keys(input).some(key => !["status", "translations"].includes(key))) {
    return NextResponse.json({ error: "상태 또는 번역만 변경할 수 있습니다." }, { status: 400 });
  }
  const patch: { status?: TopicStatus; translations?: TopicTranslations } = {};
  if ("status" in input) {
    if (typeof input.status !== "string" || !TOPIC_STATUSES.includes(input.status as TopicStatus)) {
      return NextResponse.json({ error: "상태 값이 올바르지 않습니다." }, { status: 400 });
    }
    patch.status = input.status as TopicStatus;
  }
  if ("translations" in input) {
    try { patch.translations = parseTopicTranslations(input.translations); }
    catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : "번역 형식이 올바르지 않습니다." }, { status: 400 }); }
  }

  try {
    const updated = await supabaseRest<{ id: string; status: TopicStatus }[]>(
      config,
      "topics",
      {
        method: "PATCH",
        query: `id=eq.${id}`,
        body: patch,
        returning: true,
      },
    );
    if (!updated || updated.length === 0) {
      return NextResponse.json(
        { error: "토픽을 찾을 수 없습니다." },
        { status: 404 },
      );
    }
    return NextResponse.json({ topic: updated[0] });
  } catch (error) {
    if (error instanceof SupabaseRestError) {
      const code = error.status >= 400 && error.status < 500 ? 400 : 502;
      return NextResponse.json({ error: error.message }, { status: code });
    }
    return NextResponse.json(
      { error: "백엔드에 연결하지 못했습니다." },
      { status: 502 },
    );
  }
}
