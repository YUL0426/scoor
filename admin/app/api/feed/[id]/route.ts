/**
 * 글 한 건 모더레이션 — 숨김 토글, 그리고 삭제.
 *
 * 삭제는 행을 지우지 않고 `deleted_at`을 찍는다(soft delete). 신고(`reports`)가
 * target_id로 글을 가리키고 있어서, 행이 사라지면 무엇을 처리했는지 알 수 없는
 * 신고만 큐에 남는다.
 *
 * 본문을 고치는 경로는 일부러 두지 않았다 — 이미 좋아요와 댓글이 붙은 글의
 * 내용을 바꾸면 그 반응들의 의미가 달라진다 (topics에서 status만 열어 둔 것과
 * 같은 이유).
 */

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest, SupabaseRestError } from "@/lib/server/supabase";

const NOT_CONFIGURED =
  "백엔드가 설정되지 않았습니다. admin/.env.local의 SUPABASE_URL·SUPABASE_SERVICE_ROLE_KEY를 확인해주세요.";

export async function PATCH(request: NextRequest, ctx: RouteContext<"/api/feed/[id]">) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: NOT_CONFIGURED }, { status: 503 });

  const { id } = await ctx.params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return NextResponse.json({ error: "글 id가 올바르지 않습니다." }, { status: 400 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "요청 본문 형식이 올바르지 않습니다." }, { status: 400 });
  }

  const isHidden = (body as { isHidden?: unknown })?.isHidden;
  if (typeof isHidden !== "boolean") {
    return NextResponse.json({ error: "isHidden은 true/false여야 합니다." }, { status: 400 });
  }

  return await patchPost(config, id, { is_hidden: isHidden });
}

export async function DELETE(_request: NextRequest, ctx: RouteContext<"/api/feed/[id]">) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: NOT_CONFIGURED }, { status: 503 });

  const { id } = await ctx.params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return NextResponse.json({ error: "글 id가 올바르지 않습니다." }, { status: 400 });
  }

  return await patchPost(config, id, { deleted_at: new Date().toISOString() });
}

async function patchPost(
  config: NonNullable<ReturnType<typeof supabaseAdminConfig>>,
  id: string,
  values: Record<string, unknown>
): Promise<NextResponse> {
  try {
    const updated = await supabaseRest<{ id: string }[]>(config, "posts", {
      method: "PATCH",
      query: `id=eq.${id}`,
      body: values,
      returning: true,
    });
    if (!updated || updated.length === 0) {
      return NextResponse.json({ error: "글을 찾을 수 없습니다." }, { status: 404 });
    }
    return NextResponse.json({ post: updated[0] });
  } catch (error) {
    if (error instanceof SupabaseRestError) {
      const status = error.status >= 400 && error.status < 500 ? 400 : 502;
      return NextResponse.json({ error: error.message }, { status });
    }
    return NextResponse.json({ error: "백엔드에 연결하지 못했습니다." }, { status: 502 });
  }
}
