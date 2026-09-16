import { LegalPage, LegalSection } from "@/components/layout/LegalPage";
import policy from "../../../Scoor/Resources/Legal/legal-policy.json";

const document = policy.terms.en;
export const metadata = { title: document.title };

export default function TermsPage() {
  return (
    <LegalPage title={document.title} updated={policy.version}
      altHref="/terms/ko" altLabel="한국어">
      {document.sections.map((section) => (
        <LegalSection key={section.title} heading={section.title}>
          {section.body}
        </LegalSection>
      ))}
    </LegalPage>
  );
}
