//
//  PremiseSelectionView.swift
//  NeverendingStory
//
//  Choose from 3 generated premises
//

import SwiftUI

struct PremiseSelectionView: View {
    let voiceConversation: String?

    @StateObject private var authManager = AuthManager.shared
    @State private var premises: [Premise] = []
    @State private var expandedPremise: Premise?
    @State private var isLoading = true
    @State private var isCreatingStory = false
    @State private var error: String?
    @State private var navigateToReader = false
    @State private var createdStory: Story?
    @State private var needsNewInterview = false
    @State private var navigateToNewInterview = false
    @State private var premisesId: String?
    @State private var showDiscardWarning = false
    @State private var showNameConfirmation = false
    @State private var userName = ""
    @State private var isConfirmingName = false
    @State private var selectedPremiseForCreation: Premise?

    @Environment(\.scenePhase) private var scenePhase

    init(voiceConversation: String? = nil) {
        self.voiceConversation = voiceConversation
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if isLoading {
                LoadingView("Generating your stories...")
            } else if isCreatingStory {
                BookFormationView()
            } else if let error = error {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button("Try Again") {
                        loadPremises()
                    }
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Choose Your Story")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Select the premise that speaks to you")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, 24)

                        // Premise cards
                        ForEach(premises) { premise in
                            PremiseCard(premise: premise) {
                                expandedPremise = premise
                            }
                            .padding(.horizontal, 24)
                        }

                        // Talk to Prospero button
                        TalkToProsperoButton {
                            handleTalkToProspero()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Return to the Ether", isPresented: $showDiscardWarning) {
            Button("Never mind", role: .cancel) {}
            Button("Summon Prospero", role: .destructive) {
                discardPremisesAndNavigate()
            }
        } message: {
            Text("Prospero will conjure fresh story ideas for you, but these unused tales will fade back into the ether. Are you sure?")
        }
        .navigationDestination(isPresented: $navigateToReader) {
            if let story = createdStory {
                BookReaderView(story: story)
            }
        }
        .navigationDestination(isPresented: $navigateToNewInterview) {
            OnboardingView(forceNewInterview: true)
        }
        .sheet(item: $expandedPremise) { premise in
            PremiseDetailSheet(premise: premise) {
                prepareNameConfirmation(for: premise)
            }
        }
        .sheet(isPresented: $showNameConfirmation) {
            NameConfirmationModal(
                userName: $userName,
                isConfirming: $isConfirmingName,
                onConfirm: {
                    confirmNameAndCreateStory()
                }
            )
        }
        .onAppear {
            loadPremises()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // When user returns to app during story creation,
            // the backend continues processing regardless of app state
            if newPhase == .active && isCreatingStory {
                print("📱 App returned to foreground during story creation")
                print("   Backend continues processing regardless of app state")
                // The async Task in createStory() will complete when ready
            }
        }
    }

    // MARK: - Actions

    private func loadPremises() {
        guard let userId = authManager.user?.id else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // Guard: Check if user already has a story generating
                let library = try? await APIManager.shared.getLibrary(userId: userId)
                if let stories = library {
                    let hasActiveGeneration = stories.contains { story in
                        if let progress = story.generationProgress {
                            let step = progress.currentStep
                            return story.status == "active" && step.hasPrefix("generating_")
                        }
                        return false
                    }
                    if hasActiveGeneration {
                        // Story already generating — show the formation view
                        NSLog("⚠️ User already has a story generating — showing BookFormationView")
                        isCreatingStory = true
                        isLoading = false
                        return
                    }
                }

                print("🎬 Loading premises for user...")

                // Try to fetch existing premises first
                let result = try? await APIManager.shared.getPremises(userId: userId)

                if let premisesResult = result, !premisesResult.premises.isEmpty {
                    // Unused premises exist, use them
                    print("✅ Found \(premisesResult.premises.count) unused premises")
                    premises = premisesResult.premises
                    needsNewInterview = premisesResult.needsNewInterview
                    premisesId = premisesResult.premisesId
                } else if let premisesResult = result, premisesResult.needsNewInterview {
                    // All premises used, need new interview
                    print("📝 All premises used - showing new interview option")
                    premises = []
                    needsNewInterview = true
                } else {
                    // No premises yet, generate them (takes 10-15 seconds)
                    print("🤖 No premises found, generating new ones...")
                    print("   This will take 10-15 seconds...")

                    try await APIManager.shared.generatePremises()
                    print("✅ Generation complete, fetching premises...")

                    // Now fetch the generated premises
                    let newResult = try await APIManager.shared.getPremises(userId: userId)
                    premises = newResult.premises
                    needsNewInterview = newResult.needsNewInterview
                    premisesId = newResult.premisesId
                    print("✅ Loaded \(premises.count) premises")
                }

                isLoading = false
            } catch {
                print("❌ Failed to load premises: \(error)")
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func prepareNameConfirmation(for premise: Premise) {
        guard let userId = authManager.user?.id else { return }

        selectedPremiseForCreation = premise

        // Fetch user's name from preferences
        Task {
            do {
                let prefs = try await APIManager.shared.getUserPreferences(userId: userId)
                await MainActor.run {
                    userName = prefs?["name"] as? String ?? ""
                    showNameConfirmation = true
                }
            } catch {
                NSLog("⚠️ Could not fetch user name: \(error)")
                // Show modal anyway with empty name
                await MainActor.run {
                    userName = ""
                    showNameConfirmation = true
                }
            }
        }
    }

    private func confirmNameAndCreateStory() {
        guard let premise = selectedPremiseForCreation else { return }
        guard authManager.user?.id != nil else { return }

        isConfirmingName = true

        Task {
            do {
                // Confirm name in preferences
                let trimmedName = userName.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty {
                    let success = try await APIManager.shared.confirmName(trimmedName)
                    if success {
                        NSLog("✅ User name confirmed: \(trimmedName)")
                    }
                }

                // Mark name as confirmed locally
                UserDefaults.standard.set(true, forKey: "nameConfirmed")

                await MainActor.run {
                    isConfirmingName = false
                    showNameConfirmation = false
                    // Now create the story
                    createStoryFromPremise(premise)
                }
            } catch {
                NSLog("❌ Failed to update name: \(error)")
                await MainActor.run {
                    isConfirmingName = false
                    // Continue anyway - name update is not critical
                    showNameConfirmation = false
                    createStoryFromPremise(premise)
                }
            }
        }
    }

    private func createStoryFromPremise(_ premise: Premise) {
        guard let userId = authManager.user?.id else { return }

        isCreatingStory = true

        Task {
            do {
                // Mark onboarding complete on server (persists for next app launch)
                // Do NOT update authManager.user locally here — that would trigger
                // LaunchView to swap to LibraryView and destroy BookFormationView
                try? await APIManager.shared.markOnboardingComplete(userId: userId)

                let story = try await APIManager.shared.selectPremise(
                    premiseId: premise.id,
                    userId: userId
                )

                createdStory = story

                print("✅ Story created successfully!")
                print("   Story ID: \(story.id)")
                print("   Title: \(story.title)")
                print("   User can now return to library and wait for chapters to generate")

                // Story is now generating in the background
                // User will see BookFormationView and can return to library
                // LibraryView will poll and show the book when ready
                // Keep isCreatingStory = true to show BookFormationView
            } catch {
                self.error = error.localizedDescription
                isCreatingStory = false
            }
        }
    }

    private func handleTalkToProspero() {
        // Show warning if there are unused premises
        if !premises.isEmpty {
            showDiscardWarning = true
        } else {
            // No premises to discard, go straight to interview
            navigateToNewInterview = true
        }
    }

    private func discardPremisesAndNavigate() {
        guard let premisesId = premisesId else {
            // No premises ID, just navigate
            navigateToNewInterview = true
            return
        }

        Task {
            do {
                // Call discard endpoint to log the discarded premises
                try await APIManager.shared.discardPremises(premisesId: premisesId)
                print("✅ Premises discarded successfully")
            } catch {
                print("❌ Failed to discard premises: \(error)")
                // Continue anyway - this is just a learning signal
            }

            // Navigate to new interview
            await MainActor.run {
                navigateToNewInterview = true
            }
        }
    }
}

// MARK: - Talk to Prospero Button

struct TalkToProsperoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Talk to Prospero")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Summon fresh story ideas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        PremiseSelectionView()
    }
}
