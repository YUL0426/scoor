import { Header } from "@/components/admin/header";
import { Shield, Bell, Globe, Database, Key, Users } from "lucide-react";

const SETTINGS_SECTIONS = [
  {
    icon: Shield,
    title: "Security",
    color: "#f42525",
    items: [
      { label: "Two-Factor Authentication", description: "Require 2FA for all admin accounts", enabled: true },
      { label: "Session Timeout", description: "Auto-logout after 7 days of inactivity", enabled: true },
      { label: "IP Allowlist", description: "Restrict access to trusted IPs only", enabled: false },
    ],
  },
  {
    icon: Bell,
    title: "Notifications",
    color: "#f59e0b",
    items: [
      { label: "Report Alerts", description: "Notify when new reports arrive", enabled: true },
      { label: "Emotional Spikes", description: "Alert on significant score anomalies", enabled: true },
      { label: "Daily Digest", description: "Morning summary email at 09:00 UTC", enabled: true },
    ],
  },
  {
    icon: Globe,
    title: "Platform",
    color: "#4f8ef7",
    items: [
      { label: "World Agenda Publishing", description: "Allow automated agenda suggestions", enabled: false },
      { label: "Global Feed Moderation", description: "Auto-hide content below threshold", enabled: true },
      { label: "New User Geo-detection", description: "Auto-assign country on signup", enabled: true },
    ],
  },
  {
    icon: Database,
    title: "Data",
    color: "#22c55e",
    items: [
      { label: "Data Retention (scores)", description: "Keep raw score data for 2 years", enabled: true },
      { label: "Anonymization Pipeline", description: "Strip PII from analytics exports", enabled: true },
      { label: "GDPR Request Queue", description: "Process deletion requests within 72h", enabled: true },
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
      <Header title="Settings" subtitle="Platform configuration" />
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
            <h3 className="text-sm font-semibold text-red-400 mb-3">Danger Zone</h3>
            <div className="space-y-2">
              {["Clear All Reports", "Reset Platform Stats", "Export All Data"].map((action) => (
                <button
                  key={action}
                  className="w-full flex items-center justify-between px-4 py-2.5 rounded-lg border border-red-500/20 hover:border-red-500/40 hover:bg-red-500/8 transition-all text-sm text-red-400"
                >
                  {action}
                  <span className="text-[10px] text-red-500/60 uppercase tracking-wider">Irreversible</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
