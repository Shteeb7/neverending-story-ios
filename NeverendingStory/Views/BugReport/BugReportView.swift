//
//  BugReportView.swift
//  NeverendingStory
//
//  Modal selection UI for bug reporting
//  User chooses: Report a Bug (voice/text) or Suggest a Feature (voice/text)
//  Also shows recently squashed bugs inline below
//

import SwiftUI
import UIKit

struct BugReportView: View {
    let capturedScreenshot: UIImage?
    let capturedMetadata: [String: Any]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: ReportOption?
    @State private var showVoiceInterview = false
    @State private var showTextChat = false
    @State private var consentStatus: ConsentStatus?
    @State private var showConsentScreen = false

    // Squashed reports state
    @State private var squashedReports: [BugReportNotificationManager.BugReportUpdate] = []
    @State private var isLoadingSquashed = false
    @State private var squashedError: String?

    enum ReportOption {
        case bugReport
        case suggestion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Screenshot thumbnail
                        if let screenshot = capturedScreenshot {
                            Image(uiImage: screenshot)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .padding(.top, 20)
                        }

                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "ant.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color.red.opacity(0.8))

                            Text("Talk to Peggy")
                                .font(.custom("Georgia", size: 32))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))

                            Text("Your friendly bug catcher")
                                .font(.custom("Georgia", size: 16))
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.7))
                                .italic()
                        }
                        .padding(.top, 40)

                        // Options
                        VStack(spacing: 20) {
                            OptionButton(
                                title: "Report a Bug",
                                subtitle: "Something's not working right",
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .red,
                                isSelected: selectedOption == .bugReport
                            ) {
                                selectedOption = .bugReport
                            }
                            .accessibilityIdentifier("reportBugButton")

                            OptionButton(
                                title: "Suggest a Feature",
                                subtitle: "I have an idea!",
                                icon: "lightbulb.fill",
                                iconColor: .yellow,
                                isSelected: selectedOption == .suggestion
                            ) {
                                selectedOption = .suggestion
                            }
                            .accessibilityIdentifier("suggestFeatureButton")
                        }
                        .padding(.horizontal, 24)

                        // Voice/Text Choice (only if option selected)
                        if selectedOption != nil {
                            VStack(spacing: 16) {
                                Text("How would you like to chat?")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.8))

                                HStack(spacing: 16) {
                                    // Voice button
                                    VStack(spacing: 8) {
                                        Button(action: {
                                            guard let consent = consentStatus else { return }
                                            if !consent.aiConsent {
                                                showConsentScreen = true
                                            } else if consent.voiceConsent {
                                                showVoiceInterview = true
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "mic.fill")
                                                    .font(.system(size: 18))
                                                Text("Voice")
                                                    .font(.headline)
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                (consentStatus?.voiceConsent == true) ?
                                                Color.accentColor : Color.gray
                                            )
                                            .cornerRadius(12)
                                        }
                                        .accessibilityIdentifier("voiceChatButton")
                                        .disabled(consentStatus?.voiceConsent != true)

                                        if consentStatus?.voiceConsent == false {
                                            Text("Enable voice in Settings to talk to Peggy")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }

                                    // Text button
                                    Button(action: {
                                        guard let consent = consentStatus else { return }
                                        if !consent.aiConsent {
                                            showConsentScreen = true
                                        } else {
                                            showTextChat = true
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "text.bubble.fill")
                                                .font(.system(size: 18))
                                            Text("Text")
                                                .font(.headline)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.accentColor.opacity(0.8))
                                        .cornerRadius(12)
                                    }
                                    .accessibilityIdentifier("textChatButton")
                                }
                                .padding(.horizontal, 24)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut, value: selectedOption)
                        }

                        // Recently Squashed section (inline)
                        squashedSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.6))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showVoiceInterview) {
            if let option = selectedOption {
                BugReportVoiceView(
                    reportType: option,
                    capturedScreenshot: capturedScreenshot,
                    capturedMetadata: capturedMetadata
                )
            }
        }
        .fullScreenCover(isPresented: $showTextChat) {
            if let option = selectedOption {
                BugReportTextChatView(
                    reportType: option,
                    capturedScreenshot: capturedScreenshot,
                    capturedMetadata: capturedMetadata
                )
            }
        }
        .fullScreenCover(isPresented: $showConsentScreen) {
            // TODO: Present appropriate consent screen based on consent status
            // For now, this prevents the app from crashing if consent is needed
            EmptyView()
        }
        .task {
            // Load consent status
            do {
                consentStatus = try await APIManager.shared.getConsentStatus()
            } catch {
                NSLog("⚠️ Failed to load consent status: \(error)")
                // Default to no consent if fetch fails
                consentStatus = ConsentStatus(aiConsent: false, voiceConsent: false)
            }

            // Load squashed reports
            await loadSquashedReports()
        }
    }

    // MARK: - Recently Squashed Section

    @ViewBuilder
    private var squashedSection: some View {
        VStack(spacing: 16) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Section header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("Recently Squashed")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))

                Spacer()
            }
            .padding(.horizontal, 24)

            if isLoadingSquashed {
                ProgressView()
                    .tint(Color(red: 0.9, green: 0.8, blue: 0.6))
                    .padding(.vertical, 20)
            } else if squashedReports.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "ant.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No resolved reports yet")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(squashedReports) { report in
                        SquashedReportCard(report: report)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSquashedReports() async {
        isLoadingSquashed = true
        defer { isLoadingSquashed = false }

        let since = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 86400))

        do {
            squashedReports = try await APIManager.shared.getBugReportUpdates(since: since)
        } catch {
            NSLog("⚠️ Failed to load squashed reports: \(error)")
            squashedError = error.localizedDescription
        }
    }
}

// MARK: - Option Button Component

struct OptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                    .frame(width: 50)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.green.opacity(0.6) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
    }
}

// MARK: - Squashed Report Card Component

struct SquashedReportCard: View {
    let report: BugReportNotificationManager.BugReportUpdate

    private var statusConfig: (icon: String, color: Color, label: String) {
        switch report.status {
        case "fixed":
            return ("checkmark.circle.fill", .green, "Squashed!")
        case "approved":
            return ("checkmark.seal.fill", .blue, "Approved")
        case "denied":
            return ("xmark.circle.fill", .red, "Won't Fix")
        case "deferred":
            return ("clock.fill", .orange, "Later")
        default:
            return ("questionmark.circle.fill", .gray, report.status.capitalized)
        }
    }

    private var formattedDate: String {
        guard let dateStr = report.reviewed_at else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let display = RelativeDateTimeFormatter()
            display.unitsStyle = .short
            return display.localizedString(for: date, relativeTo: Date())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateStr) {
            let display = RelativeDateTimeFormatter()
            display.unitsStyle = .short
            return display.localizedString(for: date, relativeTo: Date())
        }
        return ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status icon
            Image(systemName: statusConfig.icon)
                .font(.system(size: 22))
                .foregroundColor(statusConfig.color)
                .frame(width: 28)
                .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // User's own description — what they'll recognize
                Text(report.user_description ?? report.peggy_summary)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)

                // Status + time
                HStack(spacing: 6) {
                    Text(statusConfig.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusConfig.color)

                    if !formattedDate.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}

#Preview {
    BugReportView(
        capturedScreenshot: nil,
        capturedMetadata: [:]
    )
}
