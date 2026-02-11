//
//  OnboardingView.swift
//  NeverendingStory
//
//  Voice conversation onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var voiceManager = VoiceSessionManager()
    @State private var navigateToPremises = false
    @State private var showPermissionDenied = false
    @State private var conversationData: String? = nil
    // TEMPORARY: Bypassing voice interview for testing
    @State private var isSkippingToTest = false
    @State private var showSkipError = false
    @State private var skipErrorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // Title
                    VStack(spacing: 16) {
                        Text("Let's create your story")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Tell me what kind of story you'd love to read")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Voice visualization
                    VoiceVisualizationView(audioLevel: voiceManager.audioLevel)
                        .frame(height: 200)

                    // State-based content
                    VStack(spacing: 16) {
                        switch voiceManager.state {
                        case .idle:
                            Button(action: startVoiceSession) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                    Text("Start Voice Session")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                        case .requestingPermission:
                            ProgressView("Requesting permission...")

                        case .connecting:
                            ProgressView("Connecting...")

                        case .listening:
                            VStack(spacing: 16) {
                                Text("I'm listening...")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Button(action: endVoiceSession) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("End Session")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                        case .processing:
                            ProgressView("Processing...")

                        case .error(let message):
                            VStack(spacing: 16) {
                                Text(message)
                                    .font(.callout)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)

                                Button("Try Again") {
                                    startVoiceSession()
                                }
                                .font(.headline)
                            }

                        default:
                            EmptyView()
                        }

                        // Conversation transcript (if available)
                        if !voiceManager.conversationText.isEmpty {
                            ScrollView {
                                Text(voiceManager.conversationText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // TEMPORARY: Bypassing voice interview for testing
                    VStack(spacing: 12) {
                        Button(action: skipToTesting) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text(isSkippingToTest ? "Setting up..." : "Skip to Testing (Adult)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isSkippingToTest)

                        Button("Skip voice, choose manually") {
                            navigateToPremises = true
                        }
                        .font(.callout)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $navigateToPremises) {
                PremiseSelectionView(voiceConversation: conversationData)
            }
            .alert("Microphone Permission Required", isPresented: $showPermissionDenied) {
                Button("Open Settings", action: openSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to use voice onboarding.")
            }
            // TEMPORARY: Error alert for skip to testing
            .alert("Setup Error", isPresented: $showSkipError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(skipErrorMessage)
            }
        }
    }

    // MARK: - Actions

    private func startVoiceSession() {
        Task {
            let hasPermission = await voiceManager.requestMicrophonePermission()

            if hasPermission {
                do {
                    try await voiceManager.startSession()
                } catch {
                    print("Failed to start voice session: \(error)")
                }
            } else {
                showPermissionDenied = true
            }
        }
    }

    private func endVoiceSession() {
        // Save conversation data before ending session
        if !voiceManager.conversationText.isEmpty {
            conversationData = voiceManager.conversationText
        }

        voiceManager.endSession()

        // Navigate to premise selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateToPremises = true
        }
    }

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // TEMPORARY: Bypassing voice interview for testing
    private func skipToTesting() {
        Task {
            isSkippingToTest = true
            defer { isSkippingToTest = false }

            do {
                // Call backend with hardcoded adult preferences
                try await APIManager.shared.startOnboardingWithHardcodedPreferences()

                // Update local user state to mark onboarding as complete
                if let currentUser = AuthManager.shared.user {
                    AuthManager.shared.user = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        name: currentUser.name,
                        avatarURL: currentUser.avatarURL,
                        createdAt: currentUser.createdAt,
                        hasCompletedOnboarding: true  // Mark as completed
                    )
                }

                // Navigate to premise selection
                await MainActor.run {
                    navigateToPremises = true
                }
            } catch {
                await MainActor.run {
                    skipErrorMessage = "Failed to set up testing: \(error.localizedDescription)"
                    showSkipError = true
                }
            }
        }
    }
}

// MARK: - Voice Visualization

struct VoiceVisualizationView: View {
    let audioLevel: Float

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(0.3),
                            Color.accentColor.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.5 : 0.8)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Middle circle (reacts to audio)
            Circle()
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 150, height: 150)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
                .animation(.easeInOut(duration: 0.1), value: audioLevel)

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)

            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    OnboardingView()
}
