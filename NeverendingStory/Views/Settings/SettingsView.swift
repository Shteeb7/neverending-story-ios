//
//  SettingsView.swift
//  NeverendingStory
//
//  App-level settings (accessed from LibraryView or profile menu)
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("showBugReporter") private var showBugReporter: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $showBugReporter) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Bug Reporter")
                                .font(.body)

                            Text("Display the floating bug icon for quick bug reports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Bug Reporting")
                } footer: {
                    Text("The bug reporter lets you quickly report issues or suggest features by tapping the floating bug icon.")
                }

                Section {
                    Text("App Version")
                        .font(.body)
                    Text(appVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (build \(build))"
    }
}

#Preview {
    SettingsView()
}
