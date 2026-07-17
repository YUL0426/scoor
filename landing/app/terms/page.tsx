import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "Terms of Service",
  alternates: { canonical: "/terms" },
};

export default function TermsPage() {
  return (
    <LegalPage title="Terms of Service" updated="July 17, 2026">
      <LegalSection heading="1. Acceptance">
        By downloading or using the Scoor app or scoor.app website, you agree to
        these terms. If you do not agree, do not use Scoor.
      </LegalSection>

      <LegalSection heading="2. The service">
        Scoor is a personal scoring journal: you record a daily score with an
        optional note and view your own trends. Community and world features
        shown in the app may include sample preview content while Scoor&apos;s
        online service is under development; such content is illustrative and
        clearly labeled in the app.
      </LegalSection>

      <LegalSection heading="3. Your content">
        You own the content you create in Scoor. Because your content is stored
        on your device, you are responsible for device backups. Deleting the
        app or your account permanently removes your content.
      </LegalSection>

      <LegalSection heading="4. Acceptable use">
        You may not use Scoor to violate any law, infringe others&apos; rights,
        or attempt to disrupt or reverse-engineer the service.
      </LegalSection>

      <LegalSection heading="5. Disclaimer and liability">
        Scoor is provided &quot;as is&quot; without warranties of any kind. To
        the maximum extent permitted by law, Scoor is not liable for indirect,
        incidental, or consequential damages, or for loss of data stored on
        your device.
      </LegalSection>

      <LegalSection heading="6. Changes">
        We may update these terms as the product evolves (for example, when
        online social features launch). Material changes will be announced in
        the app or on this page before they take effect.
      </LegalSection>

      <LegalSection heading="7. Contact">
        Questions about these terms: legal@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
