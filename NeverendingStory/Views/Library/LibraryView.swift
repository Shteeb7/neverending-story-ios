//
//  LibraryView.swift
//  NeverendingStory
//
//  User's story library
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var stories: [Story] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showOnboarding = false
    @State private var selectedStory: Story?
    @State private var showFeedback = false
    @State private var pollTimer: Timer?
    @State private var showLogoutConfirmation = false

    var activeStories: [Story] {
        stories.filter { $0.status == "active" }
    }

    var pastStories: [Story] {
        stories.filter { $0.status != "active" }
    }

    // Check if any stories are currently generating
    var hasGeneratingStories: Bool {
        stories.contains { story in
            if let progress = story.generationProgress {
                return story.status == "active" && progress.chaptersGenerated < 6
            }
            return story.status == "active"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if isLoading {
                    LoadingView()
                } else if let error = error {
                    ErrorView(message: error) {
                        loadLibrary()
                    }
                } else if stories.isEmpty {
                    EmptyLibraryView {
                        showOnboarding = true
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Active stories
                            if !activeStories.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Continue Reading")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 24)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(activeStories) { story in
                                                BookCoverCard(story: story) {
                                                    selectedStory = story
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                                .padding(.top, 16)
                            }

                            // New story button — disabled during generation
                            if hasGeneratingStories {
                                // Show "writing in progress" indicator instead of new story button
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.accentColor)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Your book is being written...")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("New stories available when this one's ready")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            } else {
                                Button(action: { showOnboarding = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)

                                        Text("Start a New Story")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 24)
                            }

                            // Past stories
                            if !pastStories.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your Stories")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 24)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(pastStories) { story in
                                                BookCoverCard(story: story, isSmall: true) {
                                                    selectedStory = story
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
            }
            .confirmationDialog("Log Out", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) {
                    Task {
                        await performLogout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .navigationDestination(item: $selectedStory) { story in
                BookReaderView(story: story)
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackModalView(onSubmit: { feedback in
                    submitFeedback(feedback)
                })
            }
            .onAppear {
                NSLog("📚 LibraryView appeared - loading library")
                loadLibrary()
                // NOTE: startPollingIfNeeded() is now called from inside loadLibrary()
                // after stories are loaded, not here where stories array is still empty
            }
            .onDisappear {
                NSLog("📚 LibraryView disappeared - stopping polling")
                stopPolling()
            }
        }
    }

    // MARK: - Actions

    private func loadLibrary() {
        print("📚 LibraryView.loadLibrary() called")
        print("   authManager.user: \(authManager.user?.email ?? "nil")")
        print("   authManager.user?.id: \(authManager.user?.id ?? "nil")")
        print("   authManager.isAuthenticated: \(authManager.isAuthenticated)")

        guard let userId = authManager.user?.id else {
            print("❌ LibraryView: No user ID, returning early")
            return
        }

        print("✅ LibraryView: Found user ID, loading library...")
        isLoading = true
        error = nil

        Task {
            do {
                NSLog("📞 Calling getLibrary with userId: %@", userId)
                stories = try await APIManager.shared.getLibrary(userId: userId)
                isLoading = false
                NSLog("✅ Got %d stories", stories.count)

                // Start polling AFTER stories are loaded (not in .onAppear where array is empty)
                startPollingIfNeeded()
            } catch let apiError as APIError {
                NSLog("❌ LibraryView: APIError type: %@", String(describing: apiError))
                self.error = apiError.localizedDescription
                isLoading = false
            } catch {
                NSLog("❌ LibraryView: Other error: %@ (type: %@)", error.localizedDescription, String(describing: type(of: error)))
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func submitFeedback(_ feedback: String) {
        guard let storyId = selectedStory?.id else { return }

        Task {
            do {
                try await APIManager.shared.submitFeedback(storyId: storyId, feedback: feedback)
            } catch {
                print("Failed to submit feedback: \(error)")
            }
        }
    }

    private func performLogout() async {
        NSLog("🔓 User initiated logout")
        do {
            try await authManager.signOut()
            NSLog("✅ Logout successful")
        } catch {
            NSLog("❌ Logout failed: \(error.localizedDescription)")
            // Even if logout fails, clear local state
            authManager.user = nil
        }
    }

    // MARK: - Polling for Updates

    private func startPollingIfNeeded() {
        // Only poll if there are stories currently generating
        guard hasGeneratingStories else {
            NSLog("📊 No generating stories - skipping polling")
            return
        }

        NSLog("🔄 Starting library polling (checking every 10 seconds)")
        stopPolling() // Clear any existing timer

        // Poll every 10 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            NSLog("🔄 Polling library for updates...")
            Task { @MainActor in
                await refreshLibrary()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshLibrary() async {
        guard let userId = authManager.user?.id else { return }

        do {
            let updatedStories = try await APIManager.shared.getLibrary(userId: userId)

            // Check if any stories have new chapters
            for updated in updatedStories {
                if let existing = stories.first(where: { $0.id == updated.id }) {
                    let oldChapters = existing.generationProgress?.chaptersGenerated ?? 0
                    let newChapters = updated.generationProgress?.chaptersGenerated ?? 0

                    if newChapters > oldChapters {
                        NSLog("📖 Story '\(updated.title)' now has \(newChapters) chapters (was \(oldChapters))")
                    }
                }
            }

            stories = updatedStories

            // Stop polling if no more generating stories
            if !hasGeneratingStories {
                NSLog("✅ All stories complete - stopping polling")
                stopPolling()
            }
        } catch {
            NSLog("⚠️ Failed to refresh library: \(error.localizedDescription)")
        }
    }
}

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Your Library is Empty")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Start your first never-ending story")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Story")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                retry()
            }
            .font(.headline)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}


#Preview {
    LibraryView()
}
