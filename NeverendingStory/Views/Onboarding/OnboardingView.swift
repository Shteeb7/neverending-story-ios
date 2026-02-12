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
    @State private var isPulsing = false
    @State private var isCheckingForPremises = true
    @State private var existingPremisesFound = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if isCheckingForPremises {
                    // Show loading while checking for existing premises
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Checking your library...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
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
                                    // Show "ready to end interview" state with proceed button
                                    VStack(spacing: 20) {
                                        // Mystical portal animation
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [
                                                            Color.accentColor.opacity(0.3),
                                                            Color.accentColor.opacity(0.1),
                                                            Color.clear
                                                        ],
                                                        center: .center,
                                                        startRadius: 20,
                                                        endRadius: 60
                                                    )
                                                )
                                                .frame(width: 120, height: 120)
                                                .scaleEffect(isPulsing ? 1.2 : 1.0)
                                                .animation(
                                                    .easeInOut(duration: 1.5)
                                                    .repeatForever(autoreverses: true),
                                                    value: isPulsing
                                                )

                                            Image(systemName: "sparkles")
                                                .font(.system(size: 50))
                                                .foregroundColor(.accentColor)
                                                .symbolEffect(.pulse)
                                        }
                                        .onAppear { isPulsing = true }

                                        VStack(spacing: 8) {
                                            Text("✨ Portal Ready ✨")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)

                                            Text("Your infinite library awaits...")
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }

                                        Button(action: proceedToLibrary) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "sparkles")
                                                Text("Enter My Infinite Library")
                                                    .font(.headline)
                                                Image(systemName: "arrow.right")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                                        }
                                        .padding(.top, 8)
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
                    }
                    .padding(.horizontal, 32)

                        Spacer()
                    }
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
            .onAppear {
                checkForExistingPremises()
            }
        }
    }

    // MARK: - Actions

    private func checkForExistingPremises() {
        Task {
            guard let userId = AuthManager.shared.user?.id else {
                print("⚠️ No user ID - showing voice interview")
                await MainActor.run {
                    isCheckingForPremises = false
                }
                return
            }

            do {
                // Check if premises already exist for this user
                print("🔍 Checking for existing premises...")
                let premises = try await APIManager.shared.getPremises(userId: userId)

                if !premises.isEmpty {
                    // Premises exist! Skip voice interview and go straight to selection
                    print("✅ Found \(premises.count) existing premises - skipping interview")
                    await MainActor.run {
                        isCheckingForPremises = false
                        existingPremisesFound = true
                        navigateToPremises = true
                    }
                } else {
                    // No premises - show voice interview
                    print("📝 No premises found - showing voice interview")
                    await MainActor.run {
                        isCheckingForPremises = false
                    }
                }
            } catch {
                // Error checking - show voice interview as fallback
                print("⚠️ Error checking premises: \(error) - showing voice interview")
                await MainActor.run {
                    isCheckingForPremises = false
                }
            }
        }
    }

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

                        print("📊 Saved conversation data for later submission")
                        print("   Length: \(self.conversationData?.count ?? 0) characters")
                        print("   Preview: \(String(describing: self.conversationData?.prefix(100)))")

                        // Show "Enter Your Library" button
                        // DON'T call backend yet - wait for user to tap button
                        self.premisesReady = true
                        print("✅ Interview complete - showing 'Enter Your Library' button")
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

    private func proceedToLibrary() {
        // DON'T re-assign - conversationData was already saved in callback!
        // conversationData was set on line 223 when preferences were gathered

        print("📊 Debug - proceedToLibrary() called")
        print("   conversationData length: \(conversationData?.count ?? 0)")
        print("   voiceManager.conversationText length: \(voiceManager.conversationText.count)")
        print("   storyPreferences: \(String(describing: storyPreferences))")

        // End voice session first
        voiceManager.endSession()

        // Now call backend to save preferences and generate premises
        Task {
            guard let userId = AuthManager.shared.user?.id else {
                print("❌ No user ID available")
                await MainActor.run {
                    navigateToPremises = true // Navigate anyway to show error
                }
                return
            }

            guard let conversation = conversationData, !conversation.isEmpty else {
                print("❌ No conversation data to submit")
                print("   conversationData: \(String(describing: conversationData))")
                print("🔧 WORKAROUND: Using voiceManager.conversationText instead")

                // FALLBACK: Try using voiceManager.conversationText directly
                let fallbackConversation = voiceManager.conversationText
                if !fallbackConversation.isEmpty {
                    print("✅ Found conversation text in voiceManager: \(fallbackConversation.count) chars")
                    // Use fallback and continue
                    do {
                        try await APIManager.shared.submitVoiceConversation(userId: userId, conversation: fallbackConversation)
                        print("✅ Conversation submitted (fallback)")

                        try await APIManager.shared.generatePremises()
                        print("✅ Premises generation started")

                        await MainActor.run {
                            navigateToPremises = true
                        }
                    } catch {
                        print("❌ Fallback failed: \(error)")
                        await MainActor.run {
                            navigateToPremises = true // Navigate to show error
                        }
                    }
                } else {
                    print("❌ No conversation text anywhere!")
                    await MainActor.run {
                        navigateToPremises = true // Navigate anyway
                    }
                }
                return
            }

            do {
                // Submit conversation transcript AND preferences to backend
                print("📤 Submitting voice conversation to backend...")
                print("   Preferences: \(String(describing: storyPreferences))")
                try await APIManager.shared.submitVoiceConversation(
                    userId: userId,
                    conversation: conversation,
                    preferences: storyPreferences
                )
                print("✅ Conversation submitted and preferences saved")

                // Navigate immediately to PremiseSelectionView with loading animation
                // Premise generation will happen there (takes 10-15 seconds)
                await MainActor.run {
                    navigateToPremises = true
                }
            } catch {
                print("❌ Error submitting preferences: \(error)")
                // Still navigate - PremiseSelectionView will handle generation
                await MainActor.run {
                    navigateToPremises = true
                }
            }
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
