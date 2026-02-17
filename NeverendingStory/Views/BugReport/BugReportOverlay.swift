//
//  BugReportOverlay.swift
//  NeverendingStory
//
//  Floating bug icon overlay - draggable, persistent, always-on-top
//  Shows only if UserDefaults "showBugReporter" is true (default: true)
//

import SwiftUI
import UIKit

struct BugReportOverlay: View {
    @State private var position: CGPoint = CGPoint(x: 80, y: UIScreen.main.bounds.height - 180)  // Default bottom-left
    @State private var isDragging = false
    @State private var showBugReportView = false
    @State private var capturedData: (screenshot: UIImage?, metadata: [String: Any])?
    @AppStorage("bugReporterPosition") private var savedPosition: String = ""
    @AppStorage("showBugReporter") private var showBugReporter: Bool = true
    @ObservedObject private var apiManager = APIManager.shared

    // Screen bounds for drag constraints
    private let screenBounds = UIScreen.main.bounds
    private let iconSize: CGFloat = 60

    var body: some View {
        Group {
            // TODO: Add visibility rules for voice session (hide during active voice interviews)
            // TODO: Add visibility rules for focused reading (hide when user is deeply engaged in reading)
            // Hide when showing its own bug report view to prevent loop
            if showBugReporter && !showBugReportView {
                ZStack {
                    // Bug icon button
                    Button(action: {
                        guard !isDragging else { return }
                        // Haptic feedback
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        // Capture screenshot + metadata immediately on icon tap (spec 3a)
                        Task {
                            capturedData = await BugReportCaptureManager.shared.captureCurrentState()
                            await MainActor.run {
                                showBugReportView = true
                            }
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                // Outer glow
                                Circle()
                                    .fill((apiManager.isQueueFull ? Color.gray : Color.red).opacity(0.15))
                                    .frame(width: iconSize, height: iconSize)
                                    .blur(radius: 8)

                                // Main circle background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: apiManager.isQueueFull ? [
                                                Color.gray.opacity(0.6),
                                                Color.gray.opacity(0.4)
                                            ] : [
                                                Color.red.opacity(0.4),
                                                Color.red.opacity(0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: iconSize, height: iconSize)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                                // Bug icon
                                Image(systemName: "ant.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }
                            .opacity(apiManager.isQueueFull ? 0.5 : 1.0)

                            // Queue full badge
                            if apiManager.isQueueFull {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("!")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .disabled(apiManager.isQueueFull)
                    .position(position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                // Constrain position within screen bounds
                                let newX = max(iconSize / 2, min(screenBounds.width - iconSize / 2, value.location.x))
                                let newY = max(iconSize / 2, min(screenBounds.height - iconSize / 2, value.location.y))
                                position = CGPoint(x: newX, y: newY)
                            }
                            .onEnded { _ in
                                // Save position to UserDefaults
                                savedPosition = BugReportOverlay.encodePosition(position)

                                // Reset dragging state after a delay (prevents tap from triggering)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isDragging = false
                                }
                            }
                    )
                    .accessibilityIdentifier("bugReporterIcon")
                }
                .sheet(isPresented: $showBugReportView) {
                    BugReportView(
                        capturedScreenshot: capturedData?.screenshot,
                        capturedMetadata: capturedData?.metadata ?? [:]
                    )
                }
                .onAppear {
                    // Load saved position if available
                    if let decoded = BugReportOverlay.decodePosition(savedPosition) {
                        position = decoded
                    }
                }
            }
        }
    }

    // MARK: - Position Persistence Helpers

    private static func encodePosition(_ point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }

    private static func decodePosition(_ string: String) -> CGPoint? {
        let components = string.split(separator: ",")
        guard components.count == 2,
              let x = Double(components[0]),
              let y = Double(components[1]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        BugReportOverlay()
    }
}
