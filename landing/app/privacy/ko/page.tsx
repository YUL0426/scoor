import { LegalPage, LegalSection } from "@/components/layout/LegalPage";
import policy from "../../../../Scoor/Resources/Legal/legal-policy.json";
const document = policy.privacy.ko;
export const metadata = { title: document.title };
export default function PrivacyPage() {
  return <LegalPage title={document.title} updated={policy.version} altHref="/privacy" altLabel="English">
    {document.sections.map((section) => <LegalSection key={section.title} heading={section.title}>{section.body}</LegalSection>)}
  </LegalPage>;
}
