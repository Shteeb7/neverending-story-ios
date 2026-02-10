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
    @State private var selectedPremiseId: String?
    @State private var isLoading = true
    @State private var isCreatingStory = false
    @State private var error: String?
    @State private var navigateToReader = false
    @State private var createdStory: Story?

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
                VStack(spacing: 24) {
                    // Book forming animation
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                        .symbolEffect(.pulse)

                    Text("Your book is forming...")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
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
                            PremiseCard(
                                premise: premise,
                                isSelected: selectedPremiseId == premise.id,
                                action: {
                                    selectPremise(premise)
                                }
                            )
                            .padding(.horizontal, 24)
                        }

                        // Continue button
                        if selectedPremiseId != nil {
                            Button(action: createStory) {
                                HStack {
                                    Text("Begin Your Journey")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToReader) {
            if let story = createdStory {
                BookReaderView(story: story)
            }
        }
        .onAppear {
            loadPremises()
        }
    }

    // MARK: - Actions

    private func loadPremises() {
        guard let userId = authManager.user?.id else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // If we have voice conversation data, send it to the backend first
                if let conversation = voiceConversation, !conversation.isEmpty {
                    try await APIManager.shared.submitVoiceConversation(
                        userId: userId,
                        conversation: conversation
                    )
                }

                // Load premises (backend will use conversation data if available)
                premises = try await APIManager.shared.getPremises(userId: userId)
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func selectPremise(_ premise: Premise) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedPremiseId = premise.id
        }
    }

    private func createStory() {
        guard let premiseId = selectedPremiseId,
              let userId = authManager.user?.id else { return }

        isCreatingStory = true

        Task {
            do {
                let story = try await APIManager.shared.selectPremise(
                    premiseId: premiseId,
                    userId: userId
                )

                createdStory = story

                // Mark onboarding as complete
                try await APIManager.shared.markOnboardingComplete(userId: userId)

                // Update local user state
                if let currentUser = authManager.user {
                    authManager.user = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        name: currentUser.name,
                        avatarURL: currentUser.avatarURL,
                        createdAt: currentUser.createdAt,
                        hasCompletedOnboarding: true
                    )
                }

                // Simulate book forming animation
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                isCreatingStory = false
                navigateToReader = true
            } catch {
                self.error = error.localizedDescription
                isCreatingStory = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PremiseSelectionView()
    }
}
