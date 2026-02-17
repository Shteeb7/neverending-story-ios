//
//  BugReportNotificationManager.swift
//  NeverendingStory
//
//  Checks for bug report status updates and displays notifications
//

import Foundation
import SwiftUI

@MainActor
class BugReportNotificationManager: ObservableObject {
    static let shared = BugReportNotificationManager()

    @Published var pendingNotifications: [BugReportUpdate] = []
    @Published var showBanner: Bool = false

    private let lastCheckedKey = "bugReport_lastCheckedAt"

    struct BugReportUpdate: Codable, Identifiable {
        let id: String
        let user_description: String?  // The user's own words
        let peggy_summary: String  // Use snake_case to match API JSON
        let status: String
        let ai_priority: String?
        let category: String?
        let reviewed_at: String?
    }

    func checkForUpdates() async {
        guard let userId = AuthManager.shared.user?.id,
              !userId.isEmpty else { return }

        let since = UserDefaults.standard.string(forKey: lastCheckedKey)
            ?? ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 86400))

        do {
            let updates = try await APIManager.shared.getBugReportUpdates(since: since)
            if !updates.isEmpty {
                self.pendingNotifications = updates
                self.showBanner = true
                // Update last checked timestamp
                UserDefaults.standard.set(
                    ISO8601DateFormatter().string(from: Date()),
                    forKey: lastCheckedKey
                )
            }
        } catch {
            print("⚠️ Bug report notification check failed: \(error)")
            // Fail silently — this is a nice-to-have, not critical
        }
    }

    func dismissNotification(_ id: String) {
        pendingNotifications.removeAll { $0.id == id }
        if pendingNotifications.isEmpty {
            showBanner = false
        }
    }

    func dismissAll() {
        pendingNotifications = []
        showBanner = false
    }
}
