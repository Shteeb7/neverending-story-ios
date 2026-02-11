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
    @State private var premisesReady = false
    @State private var storyPreferences: [String: Any]? = nil

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
                                if premisesReady {
                                    // Show "ready" state with proceed button
                                    VStack(spacing: 16) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.green)

                                        Text("Story Premises Ready!")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Button(action: {
                                            voiceManager.endSession()
                                            navigateToPremises = true
                                        }) {
                                            HStack {
                                                Image(systemName: "sparkles")
                                                Text("Show Me Stories!")
                                                    .font(.headline)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                    }
                                } else {
                                    // Normal listening state
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

                    // Skip button
                    Button("Skip voice, choose manually") {
                        navigateToPremises = true
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
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
        }
    }

    // MARK: - Actions

    private func startVoiceSession() {
        Task {
            let hasPermission = await voiceManager.requestMicrophonePermission()

            if hasPermission {
                // Set up callback for when preferences are gathered
                voiceManager.onPreferencesGathered = { preferences in
                    DispatchQueue.main.async {
                        print("✅ Story preferences received in view:")
                        print("   \(preferences)")

                        self.storyPreferences = preferences
                        self.conversationData = self.voiceManager.conversationText

                        // Call backend API to generate premises with preferences
                        Task {
                            do {
                                // TODO: Update generatePremises() to accept preferences parameter
                                // For now, calling without preferences - backend should use last conversation
                                try await APIManager.shared.generatePremises()

                                DispatchQueue.main.async {
                                    self.premisesReady = true
                                    print("✅ Premises generated - user can now proceed")
                                }
                            } catch {
                                print("❌ Failed to generate premises: \(error)")
                                // Still allow user to proceed - they can try manual selection
                                DispatchQueue.main.async {
                                    self.premisesReady = true
                                }
                            }
                        }
                    }
                }

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
