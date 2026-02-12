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

    var activeStory: Story? {
        stories.first { $0.status == "active" }
    }

    var pastStories: [Story] {
        stories.filter { $0.status != "active" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                // DEBUG OVERLAY
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("DEBUG INFO:")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Text("isAuth: \(authManager.isAuthenticated ? "✅" : "❌")")
                                .font(.caption2)
                            Text("User: \(authManager.user != nil ? "✅" : "❌")")
                                .font(.caption2)
                            Text("ID: \(authManager.user?.id ?? "NIL")")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text("Email: \(authManager.user?.email ?? "NIL")")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            if let error = error {
                                Text("Error: \(error)")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.4)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                    Spacer()
                }
                .zIndex(999)

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
                            // Active story
                            if let active = activeStory {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Continue Reading")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 24)

                                    StoryCard(story: active, isActive: true) {
                                        selectedStory = active
                                    }
                                    .padding(.horizontal, 24)
                                }
                                .padding(.top, 16)
                            }

                            // New story button
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

                            // Past stories
                            if !pastStories.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Your Stories")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 24)

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)
                                        ],
                                        spacing: 16
                                    ) {
                                        ForEach(pastStories) { story in
                                            CompactStoryCard(story: story) {
                                                selectedStory = story
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
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
                    Button(action: {}) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
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
                loadLibrary()
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
        guard let storyId = activeStory?.id else { return }

        Task {
            do {
                try await APIManager.shared.submitFeedback(storyId: storyId, feedback: feedback)
            } catch {
                print("Failed to submit feedback: \(error)")
            }
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

// MARK: - Compact Story Card

struct CompactStoryCard: View {
    let story: Story
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Status badge
                Text(story.status.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                // Title
                Text(story.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chapter \(story.currentChapter)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: story.progress)
                        .tint(.accentColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LibraryView()
}
