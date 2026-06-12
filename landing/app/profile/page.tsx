import { DeepLinkRedirect } from "@/components/layout/DeepLinkRedirect";

export const metadata = { robots: { index: false } };

export default function ProfilePage() {
  return <DeepLinkRedirect path="profile" title="your profile" />;
}
