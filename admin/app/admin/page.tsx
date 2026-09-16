import { Header } from "@/components/admin/header";
import { Overview } from "@/components/admin/overview";
export default function DashboardPage() {
  return (
    <div className="workspace-content">
      <Header title="운영 개요" />
      <div className="page-body">
        <Overview />
      </div>
    </div>
  );
}
