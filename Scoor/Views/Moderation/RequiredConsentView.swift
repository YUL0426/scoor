import SwiftUI

struct LegalDocumentView: View {
    let kind: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(LegalPolicy.version).font(.caption).foregroundStyle(.secondary)
                    if let document = LegalPolicy.document(kind) {
                        ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title).font(.headline)
                                Text(section.body).font(.body).textSelection(.enabled)
                            }
                        }
                    } else {
                        Text(LegalPolicy.text("문서를 불러올 수 없습니다. 동의를 진행할 수 없습니다.", "The document is unavailable. Consent cannot proceed."))
                    }
                }.padding(20)
            }
            .navigationTitle(LegalPolicy.document(kind)?.title ?? "Scoor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(LegalPolicy.text("닫기", "Done")) { dismiss() } } }
        }
    }
}

/// Shared entry composition: examples above, account actions and notices below.
struct AccountEntryLayout<Actions: View>: View {
    var isPaused = false
    @ViewBuilder var actions: () -> Actions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let paper = Color(red: 0.98, green: 0.97, blue: 0.95)

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height < 600 || dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        stories.frame(minHeight: 350)
                        actions().padding(24).frame(maxWidth: .infinity).background(paper)
                    }
                }
                .accessibilityIdentifier("account-entry-scroll")
            } else {
                VStack(spacing: 0) {
                    stories.frame(height: geometry.size.height * 0.46)
                    ViewThatFits(in: .vertical) {
                        actionPanel
                        ScrollView { actionPanel }
                            .accessibilityIdentifier("account-entry-scroll")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(paper)
                }
            }
        }
        .background {
            VStack(spacing: 0) { ScoorPalette.bgBase; paper }.ignoresSafeArea()
        }
        .tint(.scoorRed)
        .environment(\.colorScheme, .light)
    }

    private var stories: some View {
        ConsentStoriesView(isPaused: isPaused).background(ScoorPalette.bgBase)
    }

    private var actionPanel: some View {
        actions().padding(.horizontal, 24).padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Notice beside the entry actions. Opening a document never records acceptance.
struct AccountEntryNotice: View {
    let openDocument: (String) -> Void
    var body: some View {
        VStack(spacing: 2) {
            Text(LegalPolicy.text(
                "계속하면 이용약관에 동의하고, 만 14세 이상이며 거주 국가의 가입 요건을 충족함을 확인합니다. 계정 제공에 필요한 개인정보 처리는 아래 방침에서 안내합니다.",
                "By continuing, you agree to the Terms and confirm you are 14+ and eligible to join in your country. Our Privacy Notice explains the data needed to provide your account."
            ))
            .font(.footnote)
            .foregroundStyle(Color.black.opacity(0.6))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("account-entry-notice")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { links }
                VStack(spacing: 0) { links }
            }
        }
    }

    @ViewBuilder private var links: some View {
        documentLink("terms", title: LegalPolicy.text("이용약관", "Terms of Service"))
        documentLink("privacy", title: LegalPolicy.text("개인정보처리방침", "Privacy Notice"))
    }

    private func documentLink(_ kind: String, title: String) -> some View {
        Button { openDocument(kind) } label: {
            Text(title).underline().font(.footnote.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.75))
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("legal-read-\(kind)")
    }
}

/// Only shown for an already authenticated account with no usable terms receipt,
/// or when finishing signup failed. New visitors go straight to social sign-in.
struct RequiredConsentView: View {
    @ObservedObject var service: LegalConsentService
    let userID: UUID?
    @State private var document: EntryDocument?
    @State private var showAccount = false
    @State private var saving = false
    @State private var failure: String?

    var body: some View {
        AccountEntryLayout(isPaused: document != nil || showAccount) {
            VStack(spacing: 16) {
                Text(LegalPolicy.text("오늘 점수는 몇 점인가요?", "What's your score today?"))
                    .font(.title3.weight(.bold)).foregroundStyle(.black)
                AccountEntryNotice { document = EntryDocument(kind: $0) }
                if let error = failure ?? service.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("account-entry-error")
                }
                OnboardingButton(
                    title: saving ? LegalPolicy.text("마무리하는 중…", "Finishing…") : LegalPolicy.text("계속하기", "Continue"),
                    isEnabled: userID != nil && LegalPolicy.isAvailable && !saving && !service.isChecking
                ) {
                    guard let userID else { return }
                    saving = true; failure = nil
                    Task { @MainActor in
                        defer { saving = false }
                        do { try await service.acceptTerms(action: .continueUsing, userID: userID) }
                        catch { failure = error.localizedDescription }
                    }
                }.accessibilityIdentifier("legal-continue")
                Button(LegalPolicy.text("계정 관리 · 로그아웃 · 삭제", "Manage account · Sign out · Delete")) { showAccount = true }
                    .font(.footnote).frame(minHeight: 44).accessibilityIdentifier("legal-manage-account")
                if !LegalPolicy.isAvailable {
                    Text(LegalPolicy.text("이용 안내를 불러오지 못했어요. 앱을 업데이트해 주세요.", "The notice is unavailable. Please update the app."))
                        .font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .sheet(item: $document) { LegalDocumentView(kind: $0.kind) }
        .sheet(isPresented: $showAccount) { SettingsView() }
    }
}

struct EntryDocument: Identifiable {
    let kind: String
    var id: String { kind }
}

struct ConsentGate<Content: View>: View {
    @ObservedObject var service: LegalConsentService
    @EnvironmentObject private var auth: AuthService
    let content: () -> Content
    var body: some View {
        ConsentGateContent(service: service, userID: auth.currentSession?.userID, bypass: bypassForArtwork, content: content)
        .task(id: auth.currentSession?.userID) {
            guard !bypassForArtwork, let id = auth.currentSession?.userID else { return }
            try? await service.resolve(userID: id)
        }
        .onChange(of: auth.currentSession?.userID) { old, new in
            if old != nil && new == nil { service.resetForSignOut() }
        }
    }
    private var bypassForArtwork: Bool {
        #if DEBUG
        UITestSupport.wantsAppStoreScreenshotFixture
        #else
        false
        #endif
    }
}

struct ConsentManagementView: View {
    @ObservedObject var service: LegalConsentService
    let userID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var confirmWithdrawal = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(LegalPolicy.text("이용약관 전문", "Terms of Service")) { showTerms = true }
                    Button(LegalPolicy.text("개인정보 처리 안내", "Privacy notice")) { showPrivacy = true }
                    Text(LegalPolicy.text("현재 문서 버전: ", "Current document version: ") + LegalPolicy.version)
                    Link("officialscoor@gmail.com", destination: URL(string: "mailto:officialscoor@gmail.com")!)
                }
                if userID != nil {
                    Section {
                        Text(LegalPolicy.text("계정 서비스 이용을 중단하면 새 서버 동기화와 게시를 멈춥니다. 기존 게시물은 자동으로 삭제되지 않으며, 콘텐츠 또는 계정 삭제를 별도로 요청할 수 있습니다. 선택 동의는 아래에서 따로 철회할 수 있습니다.", "Stopping account services pauses new synchronization and posting. Existing content is not automatically deleted; you can delete content or your account separately. Optional consent can be withdrawn below."))

                        Button(LegalPolicy.text("민감정보 동의 철회 및 해당 참여 내역 삭제", "Withdraw sensitive-data consent and delete those responses"), role: .destructive) {
                            busy = true; error = nil
                            Task { @MainActor in
                                defer { busy = false }
                                do { try await service.withdrawSensitiveTopics() }
                                catch { self.error = LegalPolicy.text("철회하지 못했어요. 다시 시도해 주세요.", "Withdrawal failed. Please retry.") }
                            }
                        }.disabled(busy)
                        Button(LegalPolicy.text("계정 서비스 이용 중단", "Stop account services"), role: .destructive) { confirmWithdrawal = true }
                            .disabled(busy).accessibilityIdentifier("legal-withdraw")
                        if let error { Text(error).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle(LegalPolicy.text("이용 안내와 선택 동의", "Terms and optional consent"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(LegalPolicy.text("닫기", "Done")) { dismiss() } } }
            .sheet(isPresented: $showTerms) { LegalDocumentView(kind: "terms") }
            .sheet(isPresented: $showPrivacy) { LegalDocumentView(kind: "privacy") }
            .confirmationDialog(LegalPolicy.text("계정 서비스 이용을 중단할까요?", "Stop account services?"), isPresented: $confirmWithdrawal) {
                Button(LegalPolicy.text("이용 중단", "Stop"), role: .destructive) {
                    guard let userID else { return }
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do { try await service.withdraw(userID: userID); dismiss() }
                        catch { self.error = LegalPolicy.text("서버 철회에 실패했습니다. 다시 시도하거나 고객지원으로 요청해 주세요.", "Server withdrawal failed. Retry or contact support.") }
                    }
                }
            }
        }
    }
}

struct SensitiveTopicsConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let accept: () async throws -> Void
    let onAccepted: () -> Void
    @State private var agreed = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(LegalPolicy.text("이 주제에 참여하면 정치적 견해나 건강에 관한 정보가 포함될 수 있어요.", "Participating in this topic may reveal political opinions or health information."))
                    Text(LegalPolicy.text("항목: 해당 토픽의 점수·댓글과 계정 식별자. 목적: 의견 게시와 결과 집계. 보유: 참여 내역 삭제·동의 철회·탈퇴 시까지. 점수와 댓글은 다른 이용자에게 공개되며, 익명 표시도 서버의 계정 연결은 유지합니다.", "Data: scores, comments and your account ID for these topics. Purpose: publishing opinions and aggregating results. Retained until you delete the participation, withdraw consent or close your account. Scores and comments are public; anonymous display still links to your account on the server."))
                    Text(LegalPolicy.text("동의하지 않아도 일기와 일반 주제는 이용할 수 있어요. 설정의 동의 관리에서 철회하면 해당 주제의 참여 내역도 삭제됩니다.", "You can use your journal and ordinary topics without agreeing. Withdrawal in consent settings also deletes participation in these topics."))
                    Toggle(LegalPolicy.text("[선택] 민감정보 수집·이용 및 공개에 동의합니다", "[Optional] I agree to collection, use and public disclosure of this sensitive information"), isOn: $agreed)
                    if let error { Text(error).foregroundStyle(.red) }
                    Button(LegalPolicy.text("동의하고 참여", "Agree and participate")) {
                        busy = true
                        Task { @MainActor in
                            defer { busy = false }
                            do { try await accept(); dismiss(); onAccepted() }
                            catch { self.error = LegalPolicy.text("저장하지 못했어요. 다시 시도해 주세요.", "Couldn’t save. Please try again.") }
                        }
                    }.disabled(!agreed || busy)
                }
            }
            .navigationTitle(LegalPolicy.text("민감정보 안내", "Sensitive information"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(LegalPolicy.text("취소", "Cancel")) { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
    }
}

struct ConsentGateContent<Content: View>: View {
    @ObservedObject var service: LegalConsentService
    let userID: UUID?
    var bypass = false
    let content: () -> Content
    var body: some View {
        Group {
            if bypass || userID == nil || service.permits(userID) { content() }
            else if service.isChecking { ProgressView().tint(.white).accessibilityIdentifier("account-entry-loading") }
            else { RequiredConsentView(service: service, userID: userID).id(userID) }
        }
    }
}

#if DEBUG
private final class ConsentRecoveryProtocol: URLProtocol {
    static var saves = 0
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "consent-recovery.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let saving = request.url!.path.hasSuffix("accept_account_terms")
        if saving { Self.saves += 1 }
        let accepted = Self.saves >= 2
        let status = accepted ? (saving ? 204 : 200) : 503
        let data = Data((accepted && !saving ? "true" : "").utf8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

struct ConsentRecoveryFixture: View {
    @StateObject private var service: LegalConsentService
    private let userID = UUID(uuidString: "a1000000-0000-4000-8000-000000000001")!
    init() {
        ConsentRecoveryProtocol.saves = 0
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentRecoveryProtocol.self]
        let client = SupabaseHTTPClient(config: SupabaseConfig(baseURL: URL(string: "https://consent-recovery.invalid")!, anonKey: "fixture"), tokenProvider: nil, session: URLSession(configuration: config))
        _service = StateObject(wrappedValue: LegalConsentService(client: client))
    }
    var body: some View {
        ConsentGateContent(service: service, userID: userID) {
            Text("Consent saved").accessibilityIdentifier("consent-recovery-complete")
        }.task { try? await service.resolve(userID: userID) }
    }
}
#endif
