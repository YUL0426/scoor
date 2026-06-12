//
//  SettingsView.swift
//  Scoor
//

import SwiftUI
import UserNotifications

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

    private var notifications: NotificationServiceProtocol { services.notificationService }

    /// 켜져 있는데 시스템 권한이 거부된 상태 — 설정으로 안내해야 함.
    private var needsSystemPermission: Bool {
        reminderEnabled && (authStatus == .denied)
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection

                reminderSection

                Section("Preferences") {
                    Label("Theme", systemImage: "paintbrush")
                    Label("Language", systemImage: "globe")
                }

                Section("About") {
                    Label("Privacy Policy", systemImage: "lock.shield")
                    Label("Terms of Service", systemImage: "doc.text")
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
                Text("로그아웃하면 가입 화면으로 돌아갑니다. 기기에 저장된 기록은 유지됩니다.")
            }
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
        }
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
