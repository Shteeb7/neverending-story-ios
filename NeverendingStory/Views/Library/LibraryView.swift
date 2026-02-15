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
    @State private var showNameConfirmation = false
    @State private var userName = ""
    @State private var isConfirmingName = false
    @State private var navigateToPremises = false

    var activeStories: [Story] {
        stories.filter { $0.status == "active" }
    }

    var pastStories: [Story] {
        stories.filter { $0.status != "active" }
    }

    // Check if any stories are currently generating (0 chapters, actively generating)
    // This controls whether we poll for updates
    var hasGeneratingStories: Bool {
        stories.contains { story in
            if let progress = story.generationProgress {
                let step = progress.currentStep
                return story.status == "active" && step.hasPrefix("generating_")
            }
            return false
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
                        VStack(spacing: 28) {

                            // MARK: - Hero: Currently Reading
                            if let currentStory = activeStories.first(where: { !$0.isGenerating }) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Continue Your Tale")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 24)

                                    Button(action: { selectedStory = currentStory }) {
                                        HStack(spacing: 16) {
                                            // Cover thumbnail
                                            BookCoverCard(story: currentStory, isSmall: true, action: {})
                                                .disabled(true) // Outer button handles tap
                                                .allowsHitTesting(false)

                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(currentStory.title)
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)

                                                if let genre = currentStory.genre {
                                                    Text(genre)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(Color.accentColor.opacity(0.8))
                                                        .cornerRadius(4)
                                                }

                                                // Reading progress
                                                if let progress = currentStory.generationProgress {
                                                    Text("\(progress.chaptersGenerated) of 12 Chapters written")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                Text("Continue Reading →")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.accentColor)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 8)
                                        }
                                        .padding(16)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(16)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 24)
                                }
                                .padding(.top, 8)
                            }

                            // MARK: - Currently Generating
                            if hasGeneratingStories {
                                let generatingStories = activeStories.filter { $0.isGenerating }
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Being Conjured")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 24)

                                    ForEach(generatingStories) { story in
                                        HStack(spacing: 12) {
                                            BookCoverCard(story: story, isSmall: true, action: {})
                                                .scaleEffect(0.6)
                                                .frame(width: 84, height: 126)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(story.title)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(story.progressText)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            ProgressView()
                                                .tint(.accentColor)
                                        }
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }

                            // MARK: - New Story CTA
                            if !hasGeneratingStories {
                                Button(action: { navigateToPremises = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .font(.title3)
                                        Text("Begin a New Tale")
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

                            // MARK: - Your Collection (2-column grid)
                            if !pastStories.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Your Collection")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(pastStories.count) tales")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 24)

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)
                                        ],
                                        spacing: 20
                                    ) {
                                        ForEach(pastStories) { story in
                                            VStack(alignment: .leading, spacing: 8) {
                                                BookCoverCard(story: story, isSmall: true) {
                                                    selectedStory = story
                                                }

                                                Text(story.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)

                                                if let genre = story.genre {
                                                    Text(genre)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }

                            // MARK: - Additional Active Stories (if more than one non-generating)
                            let otherActive = activeStories.filter { !$0.isGenerating }.dropFirst()
                            if !otherActive.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Also Reading")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 24)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(Array(otherActive)) { story in
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
            .navigationTitle("Your Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // User name with edit button
                        Button(action: {
                            // Pre-populate userName if empty
                            if userName.isEmpty {
                                Task {
                                    await loadUserName()
                                }
                            }
                            showNameConfirmation = true
                        }) {
                            Label("Edit Name", systemImage: "pencil")
                        }

                        Divider()

                        // Logout button
                        Button(role: .destructive, action: {
                            showLogoutConfirmation = true
                        }) {
                            Label("Log Out", systemImage: "arrow.right.square")
                        }
                    } label: {
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
            .navigationDestination(isPresented: $navigateToPremises) {
                PremiseSelectionView()
            }
            .navigationDestination(item: $selectedStory) { story in
                BookReaderView(story: story)
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackModalView(onSubmit: { feedback in
                    submitFeedback(feedback)
                })
            }
            .sheet(isPresented: $showNameConfirmation) {
                NameConfirmationModal(
                    userName: $userName,
                    isConfirming: $isConfirmingName,
                    onConfirm: {
                        confirmUserName()
                    }
                )
                .interactiveDismissDisabled(true)
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

                // Check if name confirmation is needed (only if user has stories and hasn't confirmed)
                checkNameConfirmationStatus()
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

    private func checkNameConfirmationStatus() {
        // Only check if user has stories and hasn't confirmed locally
        guard !stories.isEmpty else { return }
        guard !UserDefaults.standard.bool(forKey: "nameConfirmed") else { return }

        guard let userId = authManager.user?.id else { return }

        Task {
            do {
                // Fetch user preferences to check name_confirmed status
                struct UserPrefsResponse: Decodable {
                    let preferences: UserPreferences
                    let nameConfirmed: Bool?

                    enum CodingKeys: String, CodingKey {
                        case preferences
                        case nameConfirmed = "name_confirmed"
                    }
                }

                struct UserPreferences: Decodable {
                    let name: String?
                }

                // Call API to get user preferences
                let url = URL(string: "\(AppConfig.apiBaseURL)/onboarding/user-preferences/\(userId)")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                if let token = authManager.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(UserPrefsResponse.self, from: data)

                // Show modal if name not confirmed and we have a name
                if response.nameConfirmed != true, let name = response.preferences.name {
                    userName = name
                    showNameConfirmation = true
                }
            } catch {
                NSLog("⚠️ Failed to check name confirmation status: \(error.localizedDescription)")
            }
        }
    }

    private func confirmUserName() {
        guard !userName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isConfirmingName = true

        Task { @MainActor in
            do {
                let success = try await APIManager.shared.confirmName(userName)
                if success {
                    // Cache confirmation locally
                    UserDefaults.standard.set(true, forKey: "nameConfirmed")
                    showNameConfirmation = false
                    NSLog("✅ Name confirmed: \(userName)")
                }
                isConfirmingName = false
            } catch {
                NSLog("❌ Failed to confirm name: \(error.localizedDescription)")
                isConfirmingName = false
            }
        }
    }

    private func loadUserName() async {
        guard let userId = authManager.user?.id else { return }

        do {
            struct UserPrefsResponse: Decodable {
                let preferences: UserPreferences

                struct UserPreferences: Decodable {
                    let name: String?
                }
            }

            let url = URL(string: "\(AppConfig.apiBaseURL)/onboarding/user-preferences/\(userId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let token = authManager.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(UserPrefsResponse.self, from: data)

            if let name = response.preferences.name {
                userName = name
            }
        } catch {
            NSLog("⚠️ Failed to load user name: \(error.localizedDescription)")
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
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.7), .indigo.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 10) {
                    Text("Your shelves await")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Speak with Prospero and he'll conjure\na tale written just for you")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Begin Your First Tale")
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

            VStack(spacing: 8) {
                Text("Something went awry")
                    .font(.headline)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

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

// MARK: - Name Confirmation Modal

struct NameConfirmationModal: View {
    @Binding var userName: String
    @Binding var isConfirming: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 20) {
                        // Icon
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple.opacity(0.7), .indigo.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Header
                        VStack(spacing: 10) {
                            Text("One last enchantment...")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Did Prospero get your name right?")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Name text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your name will appear on your book covers")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Your name", text: $userName)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .disabled(isConfirming)
                    }
                    .padding(.horizontal, 32)

                    // Confirm button
                    Button(action: onConfirm) {
                        HStack(spacing: 10) {
                            if isConfirming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                Text("Looks good!")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(userName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || isConfirming)
                    .padding(.horizontal, 32)

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


#Preview {
    LibraryView()
}
