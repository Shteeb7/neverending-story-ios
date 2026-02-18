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
    let onNeedsFeedback: (() -> Void)?  // FIX 3: Called when server is waiting for checkpoint feedback

    @ObservedObject private var realtimeManager = StoryRealtimeManager.shared
    @State private var isPolling = false
    @State private var animationAmount: CGFloat = 1.0
    @State private var pollAttempts = 0  // FIX 3: Track retry count
    @State private var isWaitingForFeedback = false  // FIX 3: Deadlock detection
    let maxPollAttempts = 20  // Reduced: 10 minutes at 30-second intervals (fallback only)

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

                // Message (FIX 3: Different message when waiting for feedback)
                VStack(spacing: 16) {
                    if isWaitingForFeedback {
                        Text("Prospero is waiting for you!")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Share your thoughts about the story so far, and new chapters will be on their way.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text("Prospero is still weaving...")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("The next chapter of \(storyTitle) is being crafted")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()
            }
        }
        .onChange(of: realtimeManager.lastChapterInsert?.id) { _ in
            // Check if the chapter we're waiting for just arrived via Realtime
            if let event = realtimeManager.lastChapterInsert,
               event.storyId == storyId,
               event.chapterNumber == nextChapterNumber {
                // The chapter we're waiting for just arrived!
                isPolling = false
                onChapterReady()
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

        // FIX 3: Circuit breaker
        pollAttempts += 1

        if pollAttempts > maxPollAttempts {
            NSLog("🛑 GeneratingChaptersView: Max poll attempts reached (\(maxPollAttempts))")
            isPolling = false
            return
        }

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
                    // Check if server is waiting for feedback (every 2nd poll = 1 minute)
                    if pollAttempts % 2 == 0 {
                        await checkIfWaitingForFeedback()
                    }

                    // Fallback poll: Check again in 30 seconds (Realtime should catch it first)
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    checkChapterAvailability()
                }
            } catch {
                // On error, retry after 30 seconds (Realtime should handle normal cases)
                NSLog("❌ Error checking chapter (attempt \(pollAttempts)/\(maxPollAttempts)): \(error)")
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                checkChapterAvailability()
            }
        }
    }

    // FIX 3: Check if server is waiting for feedback
    private func checkIfWaitingForFeedback() async {
        do {
            // Fetch story to check generation_progress
            let currentState = try await APIManager.shared.getCurrentState(storyId: storyId)
            if let step = currentState.story.generationProgress?.currentStep,
               step.hasPrefix("awaiting_") {
                // Server is waiting for feedback, not generating!
                await MainActor.run {
                    isPolling = false
                    isWaitingForFeedback = true
                    onNeedsFeedback?()
                }
            }
        } catch {
            NSLog("❌ Failed to check story progress: \(error)")
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
        },
        onNeedsFeedback: {
            print("Needs feedback!")
        }
    )
}
