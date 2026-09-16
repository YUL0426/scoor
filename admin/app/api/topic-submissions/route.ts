import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest, SupabaseRestError } from "@/lib/server/supabase";

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: "백엔드가 설정되지 않았습니다." }, { status: 503 });
  try {
    const submissions = await supabaseRest(config, "topic_submissions", {
      query: "select=*&order=updated_at.desc&limit=200",
    });
    return NextResponse.json({ submissions: submissions ?? [] });
  } catch { return NextResponse.json({ error: "제안을 불러오지 못했습니다." }, { status: 502 }); }
}

export async function POST(request: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: "백엔드가 설정되지 않았습니다." }, { status: 503 });
  let body;
  try { body = await request.json(); } catch { return NextResponse.json({ error: "잘못된 요청입니다." }, { status: 400 }); }
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!body || typeof body.id !== "string" || !uuid.test(body.id) || !Number.isInteger(body.revision)
    || !["approved", "changes_requested", "rejected", "duplicate"].includes(body.action)
    || typeof body.reason !== "string" || body.reason.length > 500
    || (body.action !== "approved" && !body.reason.trim())
    || (body.action === "duplicate" && (typeof body.topicId !== "string" || !uuid.test(body.topicId)))) {
    return NextResponse.json({ error: "처리 결과와 사유, 연결할 토픽을 확인해 주세요." }, { status: 400 });
  }
  try {
    const submission = await supabaseRest(config, "rpc/review_topic_proposal", {
      method: "POST", body: { p_id: body.id, p_revision: body.revision, p_action: body.action,
        p_reason: body.reason.trim(), p_reviewer: auth.email, p_topic_id: body.action === "duplicate" ? body.topicId : null },
    });
    return NextResponse.json({ submission });
  } catch (error) {
    return NextResponse.json({ error: error instanceof SupabaseRestError ? error.message : "심사를 저장하지 못했습니다." },
      { status: error instanceof SupabaseRestError && error.status < 500 ? 409 : 502 });
  }
}
