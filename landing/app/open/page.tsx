import { DeepLinkRedirect } from "@/components/layout/DeepLinkRedirect";

export const metadata = { robots: { index: false } };

export default async function OpenPage({
  searchParams,
}: {
  searchParams: Promise<{ to?: string }>;
}) {
  const { to } = await searchParams;
  const path = (to ?? "").replace(/^\/+/, "");
  return <DeepLinkRedirect path={path} title="Scoor" />;
}
