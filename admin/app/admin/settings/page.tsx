import { Header } from "@/components/admin/header";
import { Shield, Bell, Globe, Database, Key, Users } from "lucide-react";

const SETTINGS_SECTIONS = [
  {
    icon: Shield,
    title: "보안",
    color: "#f42525",
    items: [
      { label: "2단계 인증", description: "모든 어드민 계정에 2FA 필수", enabled: true },
      { label: "세션 만료", description: "7일간 활동이 없으면 자동 로그아웃", enabled: true },
      { label: "IP 허용 목록", description: "신뢰하는 IP에서만 접근 허용", enabled: false },
    ],
  },
  {
    icon: Bell,
    title: "알림",
    color: "#f59e0b",
    items: [
      { label: "신고 알림", description: "새 신고가 접수되면 알림", enabled: true },
      { label: "감정 급변", description: "점수 이상 징후 발생 시 알림", enabled: true },
      { label: "일간 요약", description: "매일 오전 9시(UTC) 요약 메일 발송", enabled: true },
    ],
  },
  {
    icon: Globe,
    title: "플랫폼",
    color: "#4f8ef7",
    items: [
      { label: "월드 아젠다 자동 발행", description: "아젠다 자동 추천 허용", enabled: false },
      { label: "글로벌 피드 검열", description: "기준 미달 콘텐츠 자동 숨김", enabled: true },
      { label: "신규 사용자 국가 감지", description: "가입 시 국가 자동 지정", enabled: true },
    ],
  },
  {
    icon: Database,
    title: "데이터",
    color: "#22c55e",
    items: [
      { label: "데이터 보관 (점수)", description: "원본 점수 데이터를 2년간 보관", enabled: true },
      { label: "익명화 파이프라인", description: "분석 내보내기에서 개인정보 제거", enabled: true },
      { label: "GDPR 요청 큐", description: "삭제 요청을 72시간 내 처리", enabled: true },
    ],
  },
];

function Toggle({ enabled }: { enabled: boolean }) {
  return (
    <div
      className={`relative w-10 h-5 rounded-full transition-colors cursor-pointer ${
        enabled ? "bg-[#f42525]/80" : "bg-white/12"
      }`}
    >
      <div
        className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${
          enabled ? "translate-x-5" : "translate-x-0.5"
        }`}
      />
    </div>
  );
}

export default function SettingsPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="설정" subtitle="플랫폼 구성" />
      <div className="flex-1 overflow-y-auto p-6">
        <div className="max-w-2xl space-y-6">
          {SETTINGS_SECTIONS.map((section) => {
            const Icon = section.icon;
            return (
              <div key={section.title} className="bg-[#0d0d1f] border border-white/6 rounded-xl overflow-hidden">
                <div className="flex items-center gap-3 px-5 py-4 border-b border-white/5">
                  <div
                    className="w-7 h-7 rounded-lg flex items-center justify-center"
                    style={{ background: `${section.color}18` }}
                  >
                    <Icon className="h-3.5 w-3.5" style={{ color: section.color }} />
                  </div>
                  <h3 className="text-sm font-semibold text-[#f4f4f6]">{section.title}</h3>
                </div>
                <div className="divide-y divide-white/4">
                  {section.items.map((item) => (
                    <div key={item.label} className="flex items-center justify-between px-5 py-3.5 hover:bg-white/2 transition-colors">
                      <div>
                        <p className="text-sm text-[#f4f4f6]">{item.label}</p>
                        <p className="text-xs text-[#52526c] mt-0.5">{item.description}</p>
                      </div>
                      <Toggle enabled={item.enabled} />
                    </div>
                  ))}
                </div>
              </div>
            );
          })}

          {/* Danger zone */}
          <div className="bg-red-950/20 border border-red-500/20 rounded-xl p-5">
            <h3 className="text-sm font-semibold text-red-400 mb-3">위험 구역</h3>
            <div className="space-y-2">
              {["전체 신고 삭제", "플랫폼 통계 초기화", "전체 데이터 내보내기"].map((action) => (
                <button
                  key={action}
                  className="w-full flex items-center justify-between px-4 py-2.5 rounded-lg border border-red-500/20 hover:border-red-500/40 hover:bg-red-500/8 transition-all text-sm text-red-400"
                >
                  {action}
                  <span className="text-[10px] text-red-500/60 uppercase tracking-wider">되돌릴 수 없음</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
