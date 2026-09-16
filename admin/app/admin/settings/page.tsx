export const dynamic = "force-dynamic";

import { Header } from "@/components/admin/header";
import { adminAuthConfig } from "@/lib/server/env";
import { supabaseAdminConfig } from "@/lib/server/supabase";
import { ShieldCheck, Database, Info } from "lucide-react";
export default function SettingsPage() {
  const auth = Boolean(adminAuthConfig()),
    backend = Boolean(supabaseAdminConfig());
  const groups = [
    {
      title: "접근 및 보안",
      icon: ShieldCheck,
      rows: [
        {
          title: "관리자 인증",
          detail: "서버에 등록된 관리자 자격 증명으로 로그인합니다.",
          status: auth ? "설정됨" : "설정 필요",
        },
        {
          title: "세션",
          detail:
            "로그인 시점부터 7일 후 만료됩니다. 브라우저의 HttpOnly 쿠키를 사용합니다.",
          status: "7일",
        },
        {
          title: "2단계 인증 · IP 제한",
          detail: "현재 어드민에서 제공하지 않습니다.",
          status: "미지원",
        },
      ],
    },
    {
      title: "데이터 연결",
      icon: Database,
      rows: [
        {
          title: "토픽 · 피드",
          detail:
            "연결 설정 유무입니다. 실제 연결 상태는 각 콘텐츠 목록에서 확인할 수 있습니다.",
          status: backend ? "설정됨" : "설정 필요",
        },
        {
          title: "사용자 · 분석 · 알림",
          detail: "샘플 데이터를 표시하는 미리보기 화면입니다.",
          status: "미연동",
        },
        {
          title: "자동 검열 · 자동 발행",
          detail:
            "현재 구현되어 있지 않습니다. 토픽과 피드는 관리자가 직접 관리합니다.",
          status: "미지원",
        },
      ],
    },
  ];
  return (
    <div className="workspace-content">
      <Header title="설정" />
      <div className="page-body">
        <div className="page-intro">
          <div>
            <p className="ui-kicker !mb-1">워크스페이스</p>
            <h2>설정</h2>
            <p>현재 제공되는 기능과 연결 상태를 확인하세요.</p>
          </div>
          <span className="ui-pill">읽기 전용</span>
        </div>
        <div className="max-w-3xl space-y-6">
          {groups.map((g) => (
            <section className="ui-panel" key={g.title}>
              <h3 className="flex items-center gap-2 border-b border-white/8 px-5 py-4 text-sm font-medium">
                <g.icon size={15} className="text-text-secondary" />
                {g.title}
              </h3>
              {g.rows.map((row) => (
                <div key={row.title} className="ui-row !items-start">
                  <div className="flex-1">
                    <p className="text-[13px]">{row.title}</p>
                    <p className="mt-1 text-xs leading-relaxed text-text-tertiary">
                      {row.detail}
                    </p>
                  </div>
                  <span className="ui-pill">{row.status}</span>
                </div>
              ))}
            </section>
          ))}
          <p className="flex items-start gap-2 text-xs leading-relaxed text-text-tertiary">
            <Info size={15} className="shrink-0" />
            보안 자격 증명과 연결 정보는 이 화면에서 표시하거나 변경하지
            않습니다.
          </p>
        </div>
      </div>
    </div>
  );
}
