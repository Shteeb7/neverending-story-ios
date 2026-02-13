//
//  BookCompletionInterviewView.swift
//  NeverendingStory
//
//  Voice interview with Prospero after finishing chapter 12
//

import SwiftUI

struct BookCompletionInterviewView: View {
    let story: Story
    let bookNumber: Int
    let onComplete: ([String: Any]) -> Void

    @StateObject private var voiceSession = VoiceSessionManager()
    @Environment(\.dismiss) private var dismiss

    @State private var hasStarted = false
    @State private var hasPermission = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showBookComplete = false
    @State private var interviewPreferences: [String: Any] = [:]

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                if !hasStarted {
                    // Welcome screen
                    welcomeView
                } else {
                    // Interview in progress
                    interviewView
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            configureVoiceSession()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showBookComplete) {
            BookCompleteView(
                story: story,
                bookNumber: bookNumber,
                onStartSequel: {
                    // Navigate to sequel generation
                    showBookComplete = false
                    // Callback will handle navigation to SequelGenerationView
                    onComplete(interviewPreferences)
                },
                onReturnToLibrary: {
                    showBookComplete = false
                    dismiss()
                }
            )
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Prospero avatar
            ZStack {
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

                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .purple.opacity(0.4), radius: 30)

            // Title
            VStack(spacing: 16) {
                Text("You finished!")
                    .font(.system(size: 32, weight: .bold))

                Text(story.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Description
            Text("Prospero wants to hear what you thought about the story! This quick voice chat lets him sense what stirred your soul so he can conjure the perfect Book 2.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            Spacer()

            // Start button
            Button(action: { startInterview() }) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                    Text("Start Voice Interview")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
            }

            // Skip button
            Button(action: { dismiss() }) {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
    }

    private var interviewView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Status indicator
            statusView

            // Audio visualization
            if case .listening = voiceSession.state {
                audioVisualization
            }

            // Conversation text
            if !voiceSession.conversationText.isEmpty {
                ScrollView {
                    Text(voiceSession.conversationText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 300)
            }

            Spacer()

            // End button
            if case .listening = voiceSession.state {
                Button(action: { endInterview() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Interview")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if case .processing = voiceSession.state {
                Button(action: { endInterview() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Interview")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Processing indicator
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Processing interview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: 12) {
            // Prospero avatar (smaller)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    private var statusText: String {
        switch voiceSession.state {
        case .connecting:
            return "Connecting to Prospero..."
        case .connected:
            return "Connected! Prospero is ready to listen."
        case .listening:
            return "Prospero is listening..."
        case .processing:
            return "Prospero is thinking..."
        case .conversationComplete:
            return "Interview complete!"
        case .error(let message):
            return "Error: \(message)"
        default:
            return "Preparing..."
        }
    }

    private var audioVisualization: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: 3)
                    .frame(height: CGFloat.random(in: 20...60) * CGFloat(voiceSession.audioLevel + 0.2))
                    .animation(.easeInOut(duration: 0.1).repeatForever(), value: voiceSession.audioLevel)
            }
        }
        .frame(height: 80)
    }

    // MARK: - Functions

    private func configureVoiceSession() {
        // Set up callback for when interview is complete
        voiceSession.onPreferencesGathered = { preferences in
            NSLog("📝 Book completion preferences gathered: \(preferences)")
            handleInterviewComplete(preferences)
        }
    }

    private func startInterview() {
        Task {
            // Request microphone permission
            let hasPermission = await voiceSession.requestMicrophonePermission()

            guard hasPermission else {
                errorMessage = "Microphone permission is required for voice interviews"
                showError = true
                return
            }

            hasStarted = true

            do {
                try await voiceSession.startSession()
            } catch {
                errorMessage = "Failed to start voice session: \(error.localizedDescription)"
                showError = true
                hasStarted = false
            }
        }
    }

    private func endInterview() {
        voiceSession.endSession()

        // If they end early without completing, just dismiss
        if !voiceSession.isConversationComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }

    private func handleInterviewComplete(_ preferences: [String: Any]) {
        isProcessing = true

        Task {
            do {
                // Submit interview to backend
                let _ = try await APIManager.shared.submitCompletionInterview(
                    storyId: story.id,
                    transcript: voiceSession.conversationText,
                    sessionId: nil,
                    preferences: preferences
                )

                NSLog("✅ Completion interview submitted successfully")

                // Store preferences and show book complete screen
                await MainActor.run {
                    interviewPreferences = preferences
                    isProcessing = false
                    showBookComplete = true
                }

            } catch {
                NSLog("❌ Failed to submit completion interview: \(error)")
                errorMessage = "Failed to save interview: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}

#Preview {
    BookCompletionInterviewView(
        story: Story(
            id: "preview-story",
            userId: "preview-user",
            title: "The Dragon's Quest",
            status: "active",
            premiseId: nil,
            bibleId: nil,
            generationProgress: nil,
            createdAt: Date(),
            chaptersGenerated: 12,
            seriesId: nil,
            bookNumber: 1
        ),
        bookNumber: 1,
        onComplete: { preferences in
            print("Interview complete: \(preferences)")
        }
    )
}
