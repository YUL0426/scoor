//
//  SettingsView.swift
//  Scoor
//

import SwiftUI
import UserNotifications

/// 앱 전역 외형 설정. Settings의 Theme 피커가 쓰고, ScoorApp이
/// `preferredColorScheme`으로 적용한다 (P0-5).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "scoor.appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light:  return String(localized: "Light")
        case .dark:   return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 스토어 제출에 필요한 법적 문서 링크 (랜딩 사이트에서 호스팅).
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://scoor.app/privacy")!
    static let termsOfService = URL(string: "https://scoor.app/terms")!
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var coordinator: AppFlowCoordinator

    // 리마인더 설정 로컬 미러 — 서비스에서 로드하고, 변경 시 서비스로 다시 기록한다.
    @State private var reminderEnabled = true
    @State private var reminderTime = Date()
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var nextReminderText: String?
    @State private var didLoad = false
    @State private var accountEmail: String?
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var lastSyncedAt: Date?
    @State private var isSyncing = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    private var notifications: NotificationServiceProtocol { services.notificationService }

    /// 켜져 있는데 시스템 권한이 거부된 상태 — 설정으로 안내해야 함.
    private var needsSystemPermission: Bool {
        reminderEnabled && (authStatus == .denied)
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection

                if services.isBackendBacked {
                    syncSection
                }

                reminderSection

                Section("Preferences") {
                    Picker(selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance.rawValue)
                        }
                    } label: {
                        Label("Theme", systemImage: "paintbrush")
                    }
                    .accessibilityIdentifier("settings-theme-picker")

                    // 앱별 언어는 iOS 설정에서 바꾼다 (앱에 ko/ja/zh 등 로컬라이제이션 존재).
                    Button {
                        openSystemSettings()
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("settings-language-button")
                }

                Section("About") {
                    Link(destination: LegalLinks.privacyPolicy) {
                        HStack {
                            Label("Privacy Policy", systemImage: "lock.shield")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("settings-privacy-link")

                    Link(destination: LegalLinks.termsOfService) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("settings-terms-link")

                    Label("Version 1.0", systemImage: "info.circle")
                }

                Section {
                    VStack(spacing: 10) {
                        ScoorLogo(size: 30, variant: .red)
                        Text("Version 1.0 (1)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("© 2026 Scoor. All rights reserved.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.scoorRed)
                }
            }
            .task { await loadIfNeeded() }
            .confirmationDialog("로그아웃 하시겠어요?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("로그아웃", role: .destructive) { Task { await signOut() } }
                Button("취소", role: .cancel) {}
            } message: {
                Text("로그아웃하면 가입 화면으로 돌아갑니다. 기기에 저장된 기록은 유지되며, 같은 계정으로 다시 로그인하면 복원됩니다.")
            }
            .confirmationDialog("계정을 삭제하시겠어요?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
                Button("계정 및 데이터 삭제", role: .destructive) { Task { await deleteAccount() } }
                Button("취소", role: .cancel) {}
            } message: {
                Text("되돌릴 수 없습니다. 이 기기에 저장된 모든 기록(점수, 방명록, 소셜 활동)과 로그인 정보가 영구 삭제됩니다.")
            }
            .disabled(isDeletingAccount)
        }
    }

    // MARK: - Account section

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            HStack(spacing: 12) {
                Image(systemName: providerIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.scoorRed)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountEmail ?? "비공개")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityIdentifier("settings-account-email")
                    Text(providerLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .accessibilityIdentifier("settings-signout-button")

            // App Store Guideline 5.1.1(v): apps with account creation must let
            // users delete the account in-app.
            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                Label("계정 삭제", systemImage: "trash")
            }
            .accessibilityIdentifier("settings-delete-account-button")
        }
    }

    // MARK: - Sync section (spec-13 C7)

    /// Sync is deliberately almost invisible: it must never look like something the
    /// user has to manage, because journaling works whether or not it succeeded.
    /// One timestamp, and a manual retry for the case where they *want* certainty.
    @ViewBuilder
    private var syncSection: some View {
        Section {
            HStack {
                Label("마지막 동기화", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                if isSyncing {
                    ProgressView()
                } else {
                    Text(lastSyncedText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings-last-synced")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { Task { await syncNow() } }

            NavigationLink {
                BlockedUsersView(moderationService: services.moderationService)
            } label: {
                Label("차단한 사용자", systemImage: "hand.raised")
            }
            .accessibilityIdentifier("settings-blocked-users-link")
        } header: {
            Text("동기화")
        } footer: {
            Text("기록은 기기에 먼저 저장되고, 연결되면 계정으로 백업됩니다. 오프라인에서도 그대로 사용할 수 있어요.")
        }
    }

    private var lastSyncedText: String {
        guard authService.currentSession != nil else { return "로그인 필요" }
        guard let lastSyncedAt else { return "대기 중" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: lastSyncedAt, relativeTo: Date())
    }

    private func syncNow() async {
        guard let userID = authService.currentSession?.userID, !isSyncing else { return }
        isSyncing = true
        services.syncScores(userId: userID)
        // The sync itself is fire-and-forget by design (spec-13 §5); this only
        // holds the spinner long enough for the timestamp to land, so the row does
        // not flash and look like nothing happened.
        try? await Task.sleep(nanoseconds: 900_000_000)
        lastSyncedAt = await services.lastSyncedAt()
        isSyncing = false
    }

    private var providerIcon: String {
        switch authService.currentSession?.providerKind {
        case .apple:  return "apple.logo"
        case .google: return "g.circle.fill"
        case .email:  return "envelope.fill"
        case .none:   return "person.crop.circle"
        }
    }

    private var providerLabel: String {
        if let provider = authService.currentSession?.providerKind {
            return "\(provider.displayName) 계정으로 로그인됨"
        }
        return "게스트 세션"
    }

    private func signOut() async {
        authService.signOut()
        await services.userService.signOutCurrentUser()
        coordinator.resetForDebug()
        dismiss()
    }

    /// 계정 삭제: 기기에 저장된 모든 사용자 데이터(점수/소셜/방명록/프로필)와
    /// 자격 증명·세션을 제거하고 온보딩 처음으로 되돌린다.
    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        try? await services.scoreService.deleteAllScores()
        try? await services.socialService.deleteAllLocalData()
        try? await services.guestbookService.deleteAllMessages()
        await services.notificationService.setEnabled(false)
        authService.deleteAccount()
        await services.userService.signOutCurrentUser()
        coordinator.resetForDebug()
        dismiss()
    }

    // MARK: - Daily reminder section

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            Toggle(isOn: $reminderEnabled) {
                Label {
                    Text("Daily Reminder")
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.scoorRed)
                }
            }
            .tint(.scoorRed)
            .onChange(of: reminderEnabled) { _, newValue in
                Task { await handleToggle(newValue) }
            }

            if reminderEnabled {
                DatePicker(
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                ) {
                    Label("Reminder Time", systemImage: "clock")
                }
                .onChange(of: reminderTime) { _, newValue in
                    Task { await handleTimeChange(newValue) }
                }

                if needsSystemPermission {
                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Notifications are off — enable in Settings", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                } else if let nextReminderText {
                    HStack {
                        Label("Next reminder", systemImage: "calendar.badge.clock")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(nextReminderText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("\"\(NotificationCopy.title)\" — \(NotificationCopy.body)")
        }
    }

    // MARK: - Actions

    private func loadIfNeeded() async {
        if let sessionEmail = authService.currentSession?.email {
            accountEmail = sessionEmail
        } else {
            accountEmail = await services.userService.getCurrentUser()?.email
        }
        lastSyncedAt = await services.lastSyncedAt()
        guard !didLoad else {
            // 시트 재진입 시 권한 상태는 다시 확인(설정에서 바꿨을 수 있음).
            authStatus = await notifications.currentAuthorizationStatus()
            refreshNextReminder()
            return
        }
        didLoad = true
        reminderEnabled = notifications.isEnabled
        reminderTime = dateFrom(notifications.reminderTime)
        authStatus = await notifications.currentAuthorizationStatus()
        refreshNextReminder()
    }

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            // 켤 때 권한이 아직 결정 안 됐으면 요청.
            if authStatus == .notDetermined {
                _ = await notifications.requestAuthorization()
            }
            authStatus = await notifications.currentAuthorizationStatus()
        }
        await notifications.setEnabled(enabled)
        refreshNextReminder()
    }

    private func handleTimeChange(_ date: Date) async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        await notifications.setReminderTime(comps)
        refreshNextReminder()
    }

    private func refreshNextReminder() {
        if let next = notifications.nextReminderDate(), reminderEnabled, authStatus != .denied {
            let f = DateFormatter()
            f.dateFormat = "EEE, MMM d · h:mm a"
            nextReminderText = f.string(from: next)
        } else {
            nextReminderText = nil
        }
    }

    private func dateFrom(_ comps: DateComponents) -> Date {
        Calendar.current.date(
            bySettingHour: comps.hour ?? NotificationPrefs.defaultHour,
            minute: comps.minute ?? NotificationPrefs.defaultMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppServices())
}
