//
//  SettingsView.swift
//  Scoor
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Label("Profile", systemImage: "person.circle")
                    Label("Notifications", systemImage: "bell")
                }

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
        }
    }
}

#Preview {
    SettingsView()
}
