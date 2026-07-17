import { DeepLinkRedirect } from "@/components/layout/DeepLinkRedirect";

export const metadata = { robots: { index: false } };

export default async function UserPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <DeepLinkRedirect path={`user/${id}`} title="this profile" />;
}
