import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "Terms of Service",
  alternates: { canonical: "/terms", languages: { ko: "/terms/ko" } },
};

export default function TermsPage() {
  return (
    <LegalPage
      title="Terms of Service"
      updated="August 22, 2026"
      altHref="/terms/ko"
      altLabel="한국어"
    >
      <LegalSection heading="1. Acceptance">
        By downloading or using the Scoor app or scoor.app website, you agree to
        these terms. If you do not agree, do not use Scoor.
      </LegalSection>

      <LegalSection heading="2. The service">
        Scoor is a personal scoring journal with shared topics: you record a
        daily score with an optional reason, and you can score public topics and
        comment on them. Posts marked &ldquo;공식&rdquo; (official) are written
        by Scoor; everything else is written by other users.
      </LegalSection>

      <LegalSection heading="3. Your content">
        You own the content you create. By posting publicly you grant Scoor the
        limited right to store and display that content within the service so
        other users can see it. You can delete your content at any time.
      </LegalSection>

      <LegalSection heading="4. Acceptable use">
        You may not use Scoor to break the law, harass or abuse others, post
        content you have no right to post, or attempt to disrupt or
        reverse-engineer the service. Report or block anything that violates
        this from inside the app; we review reports and may hide content or
        suspend accounts.
      </LegalSection>

      <LegalSection heading="5. Account deletion">
        You can delete your account from Settings at any time. Deletion removes
        your account and content permanently and cannot be undone.
      </LegalSection>

      <LegalSection heading="6. Disclaimer and liability">
        Scoor is provided &quot;as is&quot; without warranties of any kind. To
        the maximum extent permitted by law, Scoor is not liable for indirect,
        incidental, or consequential damages, or for loss of data.
      </LegalSection>

      <LegalSection heading="7. Changes">
        We may update these terms as the product evolves. Material changes will
        be announced in the app or on this page before they take effect.
      </LegalSection>

      <LegalSection heading="8. Contact">
        Questions about these terms: legal@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
