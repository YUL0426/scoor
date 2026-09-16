import { Header } from "@/components/admin/header";
import { TopicReportsClient } from "./topic-reports-client";
import { SubmissionsClient } from "./submissions-client";
import { TopicsClient } from "./topics-client";

export default function TopicsPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header
        title="월드 토픽"
        subtitle="앱에서 오늘 점수를 매길 주제를 관리합니다"
      />
      <div className="page-body">
        <SubmissionsClient />
        <TopicReportsClient />
        <TopicsClient />
      </div>
    </div>
  );
}
