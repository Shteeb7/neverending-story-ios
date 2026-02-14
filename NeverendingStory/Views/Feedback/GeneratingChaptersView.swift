//
//  GeneratingChaptersView.swift
//  NeverendingStory
//
//  Created for Adaptive Reading Engine - Phase 2
//  Fallback screen shown when next chapter isn't ready yet
//

import SwiftUI

struct GeneratingChaptersView: View {
    let storyId: String
    let storyTitle: String
    let nextChapterNumber: Int
    let onChapterReady: () -> Void

    @State private var isPolling = false
    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Animated Prospero avatar
                ZStack {
                    // Pulsing glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.4),
                                    Color.blue.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(animationAmount)
                        .opacity(2.0 - animationAmount)

                    // Sparkles icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(animationAmount * 360))
                }
                .shadow(color: .purple.opacity(0.4), radius: 30)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        animationAmount = 1.3
                    }
                }

                // Message
                VStack(spacing: 16) {
                    Text("Prospero is still weaving...")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("The next chapter of \(storyTitle) is being crafted")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            isPolling = false
        }
    }

    // MARK: - Polling Logic

    private func startPolling() {
        isPolling = true
        checkChapterAvailability()
    }

    private func checkChapterAvailability() {
        guard isPolling else { return }

        Task {
            do {
                let isAvailable = try await APIManager.shared.checkChapterAvailability(
                    storyId: storyId,
                    chapterNumber: nextChapterNumber
                )

                if isAvailable {
                    // Chapter is ready!
                    await MainActor.run {
                        isPolling = false
                        onChapterReady()
                    }
                } else {
                    // Check again in 5 seconds
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    checkChapterAvailability()
                }
            } catch {
                // On error, retry after 5 seconds
                print("❌ Error checking chapter availability: \(error)")
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                checkChapterAvailability()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GeneratingChaptersView(
        storyId: "test-story-id",
        storyTitle: "The Chronicles of Kael",
        nextChapterNumber: 4,
        onChapterReady: {
            print("Chapter ready!")
        }
    )
}
