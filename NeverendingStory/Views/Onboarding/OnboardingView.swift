//
//  OnboardingView.swift
//  NeverendingStory
//
//  Voice conversation onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    let forceNewInterview: Bool

    @StateObject private var voiceManager = VoiceSessionManager()
    @StateObject private var textChatManager = TextChatSessionManager()
    @State private var navigateToPremises = false
    @State private var showPermissionDenied = false
    @State private var conversationData: String? = nil
    @State private var premisesReady = false
    @State private var storyPreferences: [String: Any]? = nil
    @State private var isPulsing = false
    @State private var isCheckingForPremises = true
    @State private var existingPremisesFound = false
    @State private var showDNATransfer = false
    @State private var showTextChat = false
    @State private var showVoiceConsent = false
    @State private var voiceConsent: Bool? = nil

    init(forceNewInterview: Bool = false) {
        self.forceNewInterview = forceNewInterview
    }

    var body: some View {
        if forceNewInterview {
            mainContent
        } else {
            NavigationStack {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
                // Dark magical background matching Mythweaver theme
                RadialGradient(
                    colors: [
                        Color(red: 0.1, green: 0.05, blue: 0.2), // Deep navy center
                        Color.black.opacity(0.95) // Near-black edges
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 600
                )
                .ignoresSafeArea()

                if isCheckingForPremises {
                    // Show loading while checking for existing premises
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Checking your library...")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    VStack(spacing: 40) {
                        Spacer()

                        // Title
                        VStack(spacing: 12) {
                            Text("Prospero awaits")
                                .font(.system(.title, design: .serif))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Tell me what story stirs in your soul")
                                .font(.system(.title3, design: .serif))
                                .italic()
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            if !forceNewInterview {
                                Text("Just speak naturally — you can interrupt, disagree, or ask questions anytime")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }

                            if forceNewInterview {
                                Text("Tell Prospero what you didn't like — he'll find something better")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }
                        }

                        // Voice visualization
                        VoiceVisualizationView(audioLevel: voiceManager.audioLevel)
                            .frame(height: 200)

                        // State-based content
                        VStack(spacing: 16) {
                            switch voiceManager.state {
                        case .idle:
                            // Side-by-side Speak / Write buttons
                            HStack(spacing: 12) {
                                // Speak with Prospero button
                                Button(action: startVoiceSession) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 24))
                                        Text("Speak with\nProspero")
                                            .font(.system(size: 14, weight: .semibold))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                                }

                                // Write to Prospero button
                                Button(action: startTextChat) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "pencil.line")
                                            .font(.system(size: 24))
                                        Text("Write to\nProspero")
                                            .font(.system(size: 14, weight: .semibold))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                                }
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

                                            Text("Your Mythweaver library awaits...")
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }

                                        Button(action: startDNATransfer) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "sparkles")
                                                Text("Enter the Mythweaver")
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
            .fullScreenCover(isPresented: $showTextChat) {
                TextChatView(
                    interviewType: .onboarding,  // For now, always use onboarding for text chat
                    context: nil,
                    onComplete: handleTextChatComplete
                )
            }
            .fullScreenCover(isPresented: $showDNATransfer) {
                DNATransferView(
                    userId: AuthManager.shared.user?.id ?? ""
                ) {
                    showDNATransfer = false
                    // Delay navigation to avoid simultaneous presentation changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToPremises = true
                    }
                }
            }
            .sheet(isPresented: $showVoiceConsent) {
                VoiceConsentView(
                    onConsent: {
                        voiceConsent = true
                        // Proceed with voice session after consent
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startVoiceSessionAfterConsent()
                        }
                    }
                )
            }
            .onAppear {
                checkForExistingPremises()
                loadVoiceConsentStatus()
            }
    }

    // MARK: - Actions

    private func checkForExistingPremises() {
        NSLog("🔍 OnboardingView: checkForExistingPremises() called")

        // If forcing new interview, skip checking and show interview directly
        if forceNewInterview {
            NSLog("🎙️ OnboardingView: Forcing new interview - skipping premise check")
            isCheckingForPremises = false
            return
        }

        Task {
            guard let userId = AuthManager.shared.user?.id else {
                NSLog("⚠️ OnboardingView: No user ID - showing voice interview")
                await MainActor.run {
                    isCheckingForPremises = false
                }
                return
            }

            NSLog("🔍 OnboardingView: Checking for existing premises for user: %@", userId)

            do {
                // Check if premises already exist for this user
                let result = try await APIManager.shared.getPremises(userId: userId)

                NSLog("📊 OnboardingView: API returned %d premises", result.premises.count)

                if !result.premises.isEmpty {
                    // Premises exist! Skip voice interview and go straight to selection
                    NSLog("✅ OnboardingView: Found %d existing premises - SKIPPING VOICE INTERVIEW", result.premises.count)
                    NSLog("   → Navigating directly to PremiseSelectionView")
                    await MainActor.run {
                        isCheckingForPremises = false
                        existingPremisesFound = true
                        navigateToPremises = true
                    }
                } else {
                    // No premises - show voice interview
                    NSLog("📝 OnboardingView: No premises found - SHOWING VOICE INTERVIEW")
                    await MainActor.run {
                        isCheckingForPremises = false
                    }
                }
            } catch {
                // Error checking - show voice interview as fallback
                NSLog("❌ OnboardingView: Error checking premises: %@ - showing voice interview", error.localizedDescription)
                await MainActor.run {
                    isCheckingForPremises = false
                }
            }
        }
    }

    private func startTextChat() {
        NSLog("📝 Starting text chat with Prospero")

        // Set up callback for when preferences are gathered (same as voice)
        textChatManager.onPreferencesGathered = { preferences in
            DispatchQueue.main.async {
                NSLog("✅ Text chat preferences received: \(preferences)")
                self.storyPreferences = preferences
                // No conversationData for text chat - preferences are already structured
                self.premisesReady = true
            }
        }

        showTextChat = true
    }

    private func handleTextChatComplete() {
        NSLog("✅ Text chat complete - showing DNA Transfer")
        // Text chat already triggered preferences callback
        // Same flow as voice: show DNA Transfer → generate premises
        showTextChat = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showDNATransfer = true
        }
    }

    private func loadVoiceConsentStatus() {
        Task {
            do {
                let status = try await APIManager.shared.getConsentStatus()
                await MainActor.run {
                    voiceConsent = status.voiceConsent
                }
            } catch {
                NSLog("⚠️ Failed to load voice consent status: \(error)")
            }
        }
    }

    private func startVoiceSession() {
        // Check voice consent first
        if voiceConsent == true {
            // Already have consent - proceed directly
            startVoiceSessionAfterConsent()
        } else {
            // Need to request voice consent
            showVoiceConsent = true
        }
    }

    private func startVoiceSessionAfterConsent() {
        Task {
            let hasPermission = await voiceManager.requestMicrophonePermission()

            if hasPermission {
                // Configure interview type based on whether this is a returning user
                if forceNewInterview {
                    // User rejected premises and wants to talk to Prospero again
                    await configurePremiseRejectionSession()
                } else {
                    // This is a first-time user (genuine onboarding)
                    voiceManager.interviewType = .onboarding
                }

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

    private func configurePremiseRejectionSession() async {
        guard let userId = AuthManager.shared.user?.id else {
            NSLog("⚠️ No user ID for premise rejection session - falling back to onboarding")
            voiceManager.interviewType = .onboarding
            return
        }

        // Get user's name
        let userName = await fetchUserName(userId: userId) ?? "friend"

        // Get discarded premises
        let discardedPremises = await fetchDiscardedPremises(userId: userId)

        // Get existing preferences from first interview
        let existingPreferences = await fetchExistingPreferences(userId: userId)

        // Check if they've read any books (distinguishes first-timer from returning user)
        let previousTitles = await fetchPreviousStoryTitles(userId: userId)
        let hasReadBooks = !previousTitles.isEmpty

        // If they HAVE read books before, use the returning user interview instead
        // (They're an experienced user who just didn't like today's options)
        if hasReadBooks {
            let preferredGenres = await fetchPreferredGenres(userId: userId)
            let context = ReturningUserContext(
                userName: userName,
                previousStoryTitles: previousTitles,
                preferredGenres: preferredGenres,
                discardedPremises: discardedPremises
            )
            voiceManager.interviewType = .returningUser(context: context)
            NSLog("✅ Configured RETURNING USER session for \(userName) (has \(previousTitles.count) books)")
            return
        }

        // First-time user who rejected premises — use the deep diagnostic interview
        let context = PremiseRejectionContext(
            userName: userName,
            discardedPremises: discardedPremises,
            existingPreferences: existingPreferences,
            hasReadBooks: false
        )
        voiceManager.interviewType = .premiseRejection(context: context)
        NSLog("✅ Configured PREMISE REJECTION session for \(userName) (first-time user, \(discardedPremises.count) premises rejected)")
    }

    private func fetchUserName(userId: String) async -> String? {
        do {
            // Try to get name from user_preferences table
            let result = try await APIManager.shared.getUserPreferences(userId: userId)
            if let name = result?["name"] as? String {
                return name
            }
        } catch {
            NSLog("⚠️ Could not fetch user name: \(error)")
        }
        return nil
    }

    private func fetchExistingPreferences(userId: String) async -> [String: Any]? {
        do {
            return try await APIManager.shared.getUserPreferences(userId: userId)
        } catch {
            NSLog("⚠️ Could not fetch existing preferences: \(error)")
            return nil
        }
    }

    private func fetchPreviousStoryTitles(userId: String) async -> [String] {
        do {
            let stories = try await APIManager.shared.getLibrary(userId: userId)
            return stories.map { $0.title }
        } catch {
            NSLog("⚠️ Could not fetch story titles: \(error)")
            return []
        }
    }

    private func fetchPreferredGenres(userId: String) async -> [String] {
        do {
            let result = try await APIManager.shared.getUserPreferences(userId: userId)
            if let genres = result?["genres"] as? [String] {
                return genres
            }
        } catch {
            NSLog("⚠️ Could not fetch preferred genres: \(error)")
        }
        return []
    }

    private func fetchDiscardedPremises(userId: String) async -> [(title: String, description: String, tier: String)] {
        do {
            let result = try await APIManager.shared.getUserPreferences(userId: userId)
            if let recentlyDiscarded = result?["recentlyDiscarded"] as? [[String: Any]] {
                return recentlyDiscarded.compactMap { premise in
                    guard let title = premise["title"] as? String,
                          let description = premise["description"] as? String,
                          let tier = premise["tier"] as? String else {
                        return nil
                    }
                    return (title: title, description: description, tier: tier)
                }
            }
        } catch {
            NSLog("⚠️ Could not fetch discarded premises: \(error)")
        }
        return []
    }

    private func endVoiceSession() {
        // Save conversation data before ending session
        if !voiceManager.conversationText.isEmpty {
            conversationData = voiceManager.conversationText
        }

        voiceManager.endSession()

        // Submit conversation and generate premises in background
        Task {
            guard let userId = AuthManager.shared.user?.id else { return }
            let conversation = conversationData ?? voiceManager.conversationText
            guard !conversation.isEmpty else { return }

            do {
                try await APIManager.shared.submitVoiceConversation(
                    userId: userId,
                    conversation: conversation,
                    preferences: storyPreferences
                )
                NSLog("✅ Conversation submitted from endVoiceSession")
                try await APIManager.shared.generatePremises()
                NSLog("✅ Premises generation triggered from endVoiceSession")
            } catch {
                NSLog("❌ Backend submission failed from endVoiceSession: \(error)")
            }
        }

        // Navigate to premise selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateToPremises = true
        }
    }

    private func startDNATransfer() {
        // End voice session immediately
        voiceManager.endSession()

        // Start backend submission in parallel (fire and forget)
        Task {
            guard let userId = AuthManager.shared.user?.id else { return }
            let conversation = conversationData ?? voiceManager.conversationText
            guard !conversation.isEmpty else { return }

            do {
                try await APIManager.shared.submitVoiceConversation(
                    userId: userId,
                    conversation: conversation,
                    preferences: storyPreferences
                )
                NSLog("✅ Backend submission complete during DNA Transfer")

                // Now trigger premise generation (runs during finger ceremony)
                try await APIManager.shared.generatePremises()
                NSLog("✅ Premise generation triggered during DNA Transfer")
            } catch {
                NSLog("❌ Backend submission/generation failed: \(error)")
                // DNA Transfer will handle via polling timeout + retry button
            }
        }

        // Show ceremony immediately (don't wait for backend)
        showDNATransfer = true
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
            // Outer glow effect (soft pulsing)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .opacity(isPulsing ? 0.6 : 0.8)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Middle circle (reacts to audio)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.5),
                            Color.blue.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
                .animation(.easeInOut(duration: 0.1), value: audioLevel)

            // Inner orb (main circle)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple,
                            Color.blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: .purple.opacity(0.5), radius: 20)

            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 50))
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
