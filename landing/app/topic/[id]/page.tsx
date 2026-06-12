import { DeepLinkRedirect } from "@/components/layout/DeepLinkRedirect";

export const metadata = { robots: { index: false } };

export default async function TopicPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <DeepLinkRedirect path={`topic/${id}`} title="this topic" />;
}
