import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "Privacy Policy",
  alternates: { canonical: "/privacy", languages: { ko: "/privacy/ko" } },
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      updated="August 22, 2026"
      altHref="/privacy/ko"
      altLabel="한국어"
    >
      <LegalSection heading="Overview">
        Scoor lets you score your day (0–100, with a reason) and see how others
        feel about shared topics. This policy explains what the Scoor iOS app
        and the scoor.app website handle, and where it lives.
      </LegalSection>

      <LegalSection heading="What stays on your device">
        Scoor is local-first. Your scores, notes, guestbook messages, profile,
        theme and reminder preferences are written to your device first, and the
        app keeps working with no network. Sign-in tokens are held in the iOS
        Keychain.
      </LegalSection>

      <LegalSection heading="What is sent to our servers">
        When you are signed in, Scoor backs up and syncs your daily scores
        (score, optional reason, date) and your profile (nickname, avatar emoji,
        bio) so they follow you across devices. Anything you post publicly — a
        World topic score with its optional comment, a feed comment, a like — is
        stored on our servers by design, since other people read it. Reports and
        blocks you submit are stored so we can act on them. Our backend runs on
        Supabase (managed PostgreSQL) in the Seoul region.
      </LegalSection>

      <LegalSection heading="Sign-in">
        Authentication happens directly with Apple, Google, or by email. Scoor
        receives an account identifier and, if you choose to share it, your
        email address. Email passwords are never stored in plain text.
      </LegalSection>

      <LegalSection heading="Location">
        Scoor does not use GPS and does not request location permission. A
        country shown next to a post comes from a setting you choose yourself.
      </LegalSection>

      <LegalSection heading="Account deletion">
        Settings → Account → Delete Account deletes your account. This is a real
        server-side deletion: your profile, scores, posts, comments, likes,
        reports, and blocks are removed, and your Apple sign-in token is revoked
        with Apple. Your device copy is erased at the same time. Deletion is
        permanent and cannot be undone.
      </LegalSection>

      <LegalSection heading="Notifications">
        Daily reminders are scheduled locally through iOS notifications and can
        be turned off in the app or in iOS Settings at any time.
      </LegalSection>

      <LegalSection heading="Analytics and tracking">
        The app contains no third-party analytics, advertising SDKs, or
        cross-app tracking, and does not ask for the App Tracking Transparency
        permission.
      </LegalSection>

      <LegalSection heading="Changes and contact">
        Material changes will be posted here before they take effect.
        Questions: privacy@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
