import SwiftUI

struct TopicProposalsView: View {
    @Environment(\.dismiss) private var dismiss
    let service: RemoteWorldService
    let moderation: RemoteModerationService?
    let social: SocialServiceProtocol
    @State private var proposals: [TopicProposal] = []
    @State private var notifications: [TopicProposalNotification] = []
    @State private var editing: TopicProposal?
    @State private var composing = false
    @State private var topicToOpen: WorldTopic?
    @State private var selectedTopic: WorldTopic?
    @State private var error: String?
    @State private var loading = true
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                if let error { Section { Text(error).foregroundStyle(.red); Button("다시 시도") { Task { await load() } } } }
                if loading { ProgressView("제안을 불러오는 중…") }
                if !notifications.isEmpty {
                    Section("심사 알림") {
                        ForEach(notifications) { notice in
                            Button { Task { await openNotice(notice) } } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(notice.readAt == nil ? "● " : "")\(TopicProposal.statusLabel(notice.status))").font(.caption).foregroundStyle(ScoorPalette.accent)
                                    Text(notice.title).foregroundStyle(.primary)
                                    if let reason = notice.reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                                }
                            }.disabled(busy)
                        }
                    }
                }
                Section("내 제안") {
                    if !loading && proposals.isEmpty { Text("함께 이야기하고 싶은 주제를 제안해 보세요.").foregroundStyle(.secondary) }
                    ForEach(proposals) { proposal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(proposal.statusLabel).font(.caption).foregroundStyle(ScoorPalette.accent)
                            Text(proposal.title).font(.headline)
                            if let reason = proposal.reason { Text(reason).font(.subheadline).foregroundStyle(.secondary) }
                            HStack {
                                if proposal.editable {
                                    Button("수정") { editing = proposal; composing = true }
                                    Button("철회", role: .destructive) { Task { await withdraw(proposal) } }
                                }
                                if let id = proposal.topicID { Button("토픽 보기") { Task { await openTopic(id) } } }
                            }.buttonStyle(.borderless).disabled(busy)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("내 토픽 제안")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("새 제안", systemImage: "plus") { editing = nil; composing = true }.accessibilityIdentifier("world-new-proposal") }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $composing, onDismiss: {
                selectedTopic = topicToOpen; topicToOpen = nil
                Task { await load() }
            }) {
                TopicProposalComposer(service: service, moderation: moderation, draft: composerDraft, onOpenTopic: { topic in
                    topicToOpen = topic
                    composing = false
                })
            }
            .sheet(item: $selectedTopic) { topic in
                TopicDetailView(topic: topic, socialService: social, worldService: service, moderationService: moderation)
            }
        }.preferredColorScheme(.dark)
    }
    private var composerDraft: TopicProposalDraft {
        if let editing { return TopicProposalDraft(proposal: editing) }
        return TopicProposalDraft()
    }
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            proposals = try await service.myProposals()
            notifications = try await service.proposalNotifications()
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func withdraw(_ proposal: TopicProposal) async {
        busy = true; defer { busy = false }
        do { try await service.withdrawProposal(proposal.id); await load() }
        catch { self.error = error.localizedDescription }
    }
    private func openTopic(_ id: UUID) async {
        do {
            guard let topic = try await service.topic(id: id) else { error = String(localized: "숨김 또는 차단된 토픽은 볼 수 없어요."); return }
            selectedTopic = topic
        } catch { self.error = error.localizedDescription }
    }
    private func openNotice(_ notice: TopicProposalNotification) async {
        busy = true; defer { busy = false }
        do { try await service.markProposalNotificationRead(notice.id); await load() }
        catch { self.error = error.localizedDescription }
        if let id = notice.topicID { await openTopic(id) }
    }
}

struct TopicProposalComposer: View {
    @Environment(\.dismiss) private var dismiss
    let service: RemoteWorldService
    let moderation: RemoteModerationService?
    @State var draft: TopicProposalDraft
    var onOpenTopic: (WorldTopic) -> Void
    @State private var similar: [WorldTopic] = []
    @State private var error: String?
    @State private var busy = false
    @State private var preview = false
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("검토 후 월드에 게시돼요. 최근 24시간 2건, 검토 대기 3건까지 제안할 수 있어요.")
                    Text("일반인 신상·외모 품평·개인 공격·혐오·광고는 올릴 수 없어요.").font(.caption).foregroundStyle(.secondary)
                }
                Section("함께 논의할 질문") {
                    TextField("예: 주 4일 재택근무 도입에 찬성하나요?", text: $draft.title, axis: .vertical).accessibilityIdentifier("proposal-title")
                    Text("\(draft.title.count)/80자").font(.caption).foregroundStyle(.secondary)
                    Picker("카테고리", selection: $draft.category) {
                        ForEach(WorldCategory.allCases) { category in Text(category.label).tag(category.rawValue) }
                    }
                    TextField("배경 설명 (10~200자)", text: $draft.subtitle, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("proposal-description")
                }
                if !similar.isEmpty {
                    Section("비슷한 기존 토픽에 참여해 보세요") {
                        ForEach(similar) { topic in Button(topic.title) { onOpenTopic(topic) } }
                    }
                }
                Section("질문의 종류와 출처") {
                    Picker("종류", selection: $draft.kind) { Text("의견·논의").tag("discussion"); Text("뉴스·사건").tag("news") }
                    TextField(draft.kind == "news" ? String(localized: "출처 URL (필수)") : String(localized: "출처 URL (선택)"), text: $draft.sourceURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                Section("점수 기준") {
                    TextField("0점의 의미", text: $draft.low)
                    TextField("100점의 의미", text: $draft.high)
                    Text("참여가 시작되면 질문과 점수 기준은 바꿀 수 없어요.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Section { Button("미리보기") { preview = true }.disabled(draft.validationMessage != nil || busy).accessibilityIdentifier("proposal-preview") }
                if let message = draft.validationMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            .disabled(busy)
            .navigationTitle(draft.revision == nil ? String(localized: "토픽 제안") : String(localized: "제안 수정"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(busy) } }
            .task(id: draft.title) {
                guard draft.title.count >= 2 else { similar = []; return }
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    let results = try await service.searchTopics(draft.title)
                    try Task.checkCancellation()
                    similar = results
                } catch is CancellationError { } catch { similar = [] }
            }
            .sheet(isPresented: $preview) {
                NavigationStack {
                    List {
                        Section("커뮤니티 제안 · 게시 미리보기") {
                            Text(draft.title).font(.title3.bold())
                            Text(draft.subtitle)
                            Text("0: \(draft.low) · 100: \(draft.high)")
                            if !draft.sourceURL.isEmpty { Text(draft.sourceURL).font(.caption) }
                        }
                        Section { Button("검토 요청 보내기") { preview = false; Task { await submit() } }.accessibilityIdentifier("proposal-submit") }
                    }.navigationTitle("미리보기")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("돌아가기") { preview = false } } }
                }
            }

            .alert("제안을 보냈어요", isPresented: $submitted) { Button("내 제안 확인") { dismiss() } }
                message: { Text("검토 결과는 내 토픽 제안의 심사 알림에서 확인할 수 있어요.") }
        }.preferredColorScheme(.dark)
    }

    private func submit() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { try await service.submitProposal(draft); submitted = true }
        catch { self.error = error.localizedDescription }
    }
}
