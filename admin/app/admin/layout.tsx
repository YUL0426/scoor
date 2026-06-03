import { Sidebar } from "@/components/admin/sidebar";
import { AuthProvider } from "@/providers/auth-provider";
import type { ReactNode } from "react";

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <div className="flex h-screen overflow-hidden bg-[#060610]">
        <Sidebar />
        <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
          {children}
        </div>
      </div>
    </AuthProvider>
  );
}
