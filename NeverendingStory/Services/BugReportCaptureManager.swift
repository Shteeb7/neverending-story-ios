//
//  BugReportCaptureManager.swift
//  NeverendingStory
//
//  Captures screenshot + app state metadata for bug reporting
//  Must complete in under 200ms
//

import UIKit
import Foundation
import Network
import Darwin

@MainActor
class BugReportCaptureManager: ObservableObject {
    static let shared = BugReportCaptureManager()

    // Screen tracking - set by major views in .onAppear
    static var currentScreen: String = "Unknown"

    // Captured data (stored in memory until submission)
    @Published var capturedScreenshot: UIImage?
    @Published var capturedMetadata: [String: Any]?

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var currentNetworkStatus: String = "unknown"

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self?.currentNetworkStatus = "wifi"
                    } else if path.usesInterfaceType(.cellular) {
                        self?.currentNetworkStatus = "cellular"
                    } else {
                        self?.currentNetworkStatus = "other"
                    }
                } else {
                    self?.currentNetworkStatus = "none"
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Capture Screenshot + Metadata

    /// Captures current screen as screenshot + full app state metadata
    /// Must complete in under 200ms
    func captureCurrentState() async -> (screenshot: UIImage?, metadata: [String: Any]) {
        let startTime = Date()

        // Capture screenshot FIRST (before any UI changes)
        let screenshot = await captureScreenshot()

        // Build metadata in parallel
        let metadata = await buildMetadata()

        // Store in memory
        self.capturedScreenshot = screenshot
        self.capturedMetadata = metadata

        let duration = Date().timeIntervalSince(startTime)
        NSLog("🐞 BugReportCapture: Completed in %.0fms", duration * 1000)

        return (screenshot, metadata)
    }

    // MARK: - Screenshot Capture

    private func captureScreenshot() async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows
                    .first(where: { $0.isKeyWindow }) else {
                    NSLog("⚠️ BugReportCapture: No key window found")
                    continuation.resume(returning: nil)
                    return
                }

                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let screenshot = renderer.image { context in
                    window.layer.render(in: context.cgContext)
                }

                NSLog("✅ BugReportCapture: Screenshot captured (%dx%d)",
                      Int(screenshot.size.width), Int(screenshot.size.height))
                continuation.resume(returning: screenshot)
            }
        }
    }

    // MARK: - Metadata Builder

    private func buildMetadata() async -> [String: Any] {
        var metadata: [String: Any] = [:]

        // Device info (hardware identifier, no PII)
        metadata["device_model"] = getDeviceModel()
        metadata["ios_version"] = UIDevice.current.systemVersion

        // App version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            metadata["app_version"] = "\(appVersion) (build \(buildNumber))"
        }

        // Timestamp
        let formatter = ISO8601DateFormatter()
        metadata["timestamp"] = formatter.string(from: Date())

        // Current screen
        metadata["current_screen"] = BugReportCaptureManager.currentScreen

        // User ID
        if let userId = AuthManager.shared.user?.id {
            metadata["user_id"] = userId
        }

        // Reading state (only if on BookReaderView)
        if BugReportCaptureManager.currentScreen == "BookReaderView" {
            metadata["reading_state"] = await captureReadingState()
        }

        // Last API calls (from ring buffer)
        metadata["last_api_calls"] = APIManager.shared.getRecentAPICalls()

        // Auth state
        metadata["auth_state"] = AuthManager.shared.isAuthenticated ? "authenticated" : "unauthenticated"

        // Network status
        metadata["network_status"] = currentNetworkStatus

        return metadata
    }

    private func captureReadingState() async -> [String: Any] {
        let readingState = ReadingStateManager.shared
        var state: [String: Any] = [:]

        if let story = readingState.currentStory {
            state["story_id"] = story.id
            state["story_title"] = story.title
            state["current_chapter_index"] = readingState.currentChapterIndex
            state["current_chapter_number"] = readingState.currentChapterIndex + 1
            state["scroll_progress"] = readingState.scrollPercentage / 100.0
            state["chapters_loaded"] = readingState.chapters.count

            if let progress = story.generationProgress {
                state["generation_progress"] = progress.currentStep
            }
        }

        return state
    }

    // MARK: - Device Model Detection

    /// Get hardware identifier (e.g., "iPhone16,1") without PII
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return identifier  // Returns e.g., "iPhone16,1" for iPhone 15 Pro or "arm64" in simulator
    }

    // MARK: - Clear Captured Data

    func clearCapturedData() {
        capturedScreenshot = nil
        capturedMetadata = nil
    }
}
