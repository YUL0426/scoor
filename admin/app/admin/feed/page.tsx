import { Header } from "@/components/admin/header";
import { FeedClient } from "./feed-client";

export default function FeedPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="피드" subtitle="앱 Feed 탭에 보이는 글을 등록하고 관리합니다" />
      <div className="flex-1 overflow-y-auto p-6">
        <FeedClient />
      </div>
    </div>
  );
}
