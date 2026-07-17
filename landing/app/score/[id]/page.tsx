import { DeepLinkRedirect } from "@/components/layout/DeepLinkRedirect";

export const metadata = { robots: { index: false } };

export default async function ScorePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <DeepLinkRedirect path={`score/${id}`} title={`score #${id}`} />;
}
