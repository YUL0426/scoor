import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest } from "@/lib/server/supabase";
export async function GET() {
  const auth = await requireAdmin(); if (!auth.ok) return auth.response;
  const config = supabaseAdminConfig(); if (!config) return NextResponse.json({ error: "백엔드 미설정" }, { status: 503 });
  try {
    const reports = await supabaseRest(config, "reports", { query: "select=id,target_id,reason,detail,created_at&target_type=eq.topic&status=eq.open&order=created_at.asc&limit=200" });
    return NextResponse.json({ reports: reports ?? [] });
  } catch { return NextResponse.json({ error: "신고를 불러오지 못했습니다." }, { status: 502 }); }
}
export async function POST(request: Request) {
  const auth = await requireAdmin(); if (!auth.ok) return auth.response;
  const config = supabaseAdminConfig(); if (!config) return NextResponse.json({ error: "백엔드 미설정" }, { status: 503 });
  let body; try { body = await request.json(); } catch { return NextResponse.json({ error: "잘못된 요청입니다." }, { status: 400 }); }
  if (!body || typeof body.hide !== "boolean" || typeof body.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.id)) return NextResponse.json({ error: "잘못된 요청입니다." }, { status: 400 });
  try {
    await supabaseRest(config, "rpc/resolve_topic_report", { method: "POST", body: { p_id: body.id, p_hide: body.hide } });
    return NextResponse.json({ ok: true });
  } catch { return NextResponse.json({ error: "신고 처리에 실패했습니다." }, { status: 502 }); }
}
