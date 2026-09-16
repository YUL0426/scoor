import { Sidebar } from "@/components/admin/sidebar";
import { AuthProvider } from "@/providers/auth-provider";
import type { ReactNode } from "react";
export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <div className="flex h-dvh overflow-hidden bg-bg-base">
        <a
          href="#admin-content"
          className="sr-only focus:not-sr-only focus:fixed focus:z-[100] focus:bg-bg-overlay focus:p-3"
        >
          본문으로 이동
        </a>
        <Sidebar />
        <main id="admin-content" className="workspace-content" tabIndex={-1}>
          {children}
        </main>
      </div>
    </AuthProvider>
  );
}
