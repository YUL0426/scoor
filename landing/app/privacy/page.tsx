import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "Privacy Policy",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="July 17, 2026">
      <LegalSection heading="Overview">
        Scoor lets you score your day (0–100, with a reason) and explore how the
        world feels. This policy explains what information the Scoor iOS app and
        the scoor.app website handle, and where it lives.
      </LegalSection>

      <LegalSection heading="Data stored on your device">
        Your scores, notes, guestbook messages, profile (nickname, avatar, bio),
        theme and reminder preferences are stored locally on your device. Scoor
        does not currently operate a backend service: this content is not
        uploaded to Scoor servers and is not visible to other users.
      </LegalSection>

      <LegalSection heading="Sign-in">
        When you sign in with Apple or Google, authentication happens directly
        with that provider. Scoor receives your account identifier, and — if you
        choose to share them — your email address and name, which are stored
        only on your device (tokens in the iOS Keychain). If you create an
        email account, your password is never stored in plain text: only a
        salted cryptographic hash is kept in the Keychain on your device.
      </LegalSection>

      <LegalSection heading="Account deletion">
        You can delete your account and all associated data at any time from
        Settings → Account → Delete Account in the app. This permanently
        removes your scores, messages, profile, credentials, and sign-in
        session from the device.
      </LegalSection>

      <LegalSection heading="Notifications">
        Daily reminders are scheduled locally through iOS notifications and can
        be turned off in the app or in iOS Settings at any time.
      </LegalSection>

      <LegalSection heading="Analytics and tracking">
        The app does not include third-party analytics, advertising SDKs, or
        cross-app tracking.
      </LegalSection>

      <LegalSection heading="Changes and contact">
        If Scoor introduces online features (such as a shared social feed), this
        policy will be updated before those features launch. Questions:
        privacy@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
