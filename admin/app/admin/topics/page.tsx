import { Header } from "@/components/admin/header";
import { TopicsClient } from "./topics-client";

export default function TopicsPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="World Topics" subtitle="Curate what the app scores today" />
      <div className="flex-1 overflow-y-auto p-6">
        <TopicsClient />
      </div>
    </div>
  );
}
