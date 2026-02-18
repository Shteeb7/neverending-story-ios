//
//  BugFixBanner.swift
//  NeverendingStory
//
//  Displays notifications when bug reports are resolved
//

import SwiftUI

struct BugFixBanner: View {
    let notifications: [BugReportNotificationManager.BugReportUpdate]
    let onDismiss: (String) -> Void
    let onDismissAll: () -> Void

    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(notifications) { update in
                notificationCard(for: update)
            }

            if notifications.count > 1 {
                dismissAllButton
            }
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    private func notificationCard(for update: BugReportNotificationManager.BugReportUpdate) -> some View {
        HStack(spacing: 12) {
            statusIcon(for: update.status)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your report '\(update.peggy_summary)' \(statusMessage(for: update))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let priority = update.ai_priority {
                    Text("Priority: \(priority)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button(action: { onDismiss(update.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(14)
            }
        }
        .padding(12)
        .background(statusColor(for: update.status).opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var dismissAllButton: some View {
        Button(action: onDismissAll) {
            Text("Dismiss All")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func statusIcon(for status: String) -> some View {
        Group {
            switch status {
            case "fixed":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "approved":
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.blue)
            case "denied":
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            case "deferred":
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            default:
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "fixed":
            return .green
        case "approved":
            return .blue
        case "denied":
            return .gray
        case "deferred":
            return .orange
        default:
            return .gray
        }
    }

    private func statusMessage(for update: BugReportNotificationManager.BugReportUpdate) -> String {
        switch update.status {
        case "fixed": return "has been fixed! 🎉"
        case "approved": return "has been approved and a fix is in progress"
        case "denied": return "was reviewed and closed"
        case "deferred": return "has been noted for a future update"
        default: return "has been updated"
        }
    }

    private func startAutoDismissTimer() {
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    onDismissAll()
                }
            }
        }
    }
}
