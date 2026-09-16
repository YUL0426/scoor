import SwiftUI

/// One entry screen: examples, provider sign-in, and an adjacent terms notice.
struct SignupWelcomeView: View {
    var onApple: () -> Void
    var onGoogle: () -> Void
    var onEmail: () -> Void
    @State private var document: EntryDocument?

    var body: some View {
        AccountEntryLayout(isPaused: document != nil) {
            VStack(spacing: 12) {
                Text(LegalPolicy.text("오늘 점수는 몇 점인가요?", "What's your score today?"))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)
                OnboardingButton(title: LegalPolicy.text("Apple로 계속하기", "Continue with Apple"),
                                 style: .applePill, isEnabled: LegalPolicy.isAvailable,
                                 systemImage: "apple.logo", action: onApple)
                    .accessibilityIdentifier("signup-apple")
                if GoogleSignInController.isConfigured || UITestSupport.wantsCleanState {
                    OnboardingButton(title: LegalPolicy.text("Google로 계속하기", "Continue with Google"),
                                     style: .googlePill, isEnabled: LegalPolicy.isAvailable,
                                     systemImage: "g.circle.fill", action: onGoogle)
                        .accessibilityIdentifier("signup-google")
                }
                AccountEntryNotice { document = EntryDocument(kind: $0) }
                Button(LegalPolicy.text("이메일로 계속하기", "Continue with Email"), action: onEmail)
                    .font(.footnote).foregroundStyle(Color.black.opacity(0.6))
                    .frame(minHeight: 44).disabled(!LegalPolicy.isAvailable)
                if !LegalPolicy.isAvailable {
                    Text(LegalPolicy.text("이용 안내를 불러오지 못했어요. 앱을 업데이트해 주세요.", "The notice is unavailable. Please update the app."))
                        .font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .sheet(item: $document) { LegalDocumentView(kind: $0.kind) }
    }
}

#Preview { SignupWelcomeView(onApple: {}, onGoogle: {}, onEmail: {}) }
