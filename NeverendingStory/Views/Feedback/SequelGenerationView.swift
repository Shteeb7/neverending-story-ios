//
//  SequelGenerationView.swift
//  NeverendingStory
//
//  Progress view for generating book sequels
//

import SwiftUI

struct SequelGenerationView: View {
    let book1Story: Story
    let bookNumber: Int
    let userPreferences: [String: Any]
    let onComplete: (Story) -> Void

    @State private var generationState: GenerationState = .analyzing
    @State private var statusMessage = "Analyzing Book \(1)..."
    @State private var progress: Double = 0.0
    @State private var book2Story: Story?
    @State private var isGenerating = false
    @Environment(\.dismiss) private var dismiss

    enum GenerationState {
        case analyzing
        case creatingBible
        case generatingChapters
        case complete
        case error(String)
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.indigo.opacity(0.3), Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Prospero avatar with animation
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
                        .rotationEffect(.degrees(progress * 360))
                }
                .shadow(color: .purple.opacity(0.4), radius: 30)

                // Status text
                VStack(spacing: 16) {
                    Text("Conjuring Book \(bookNumber)")
                        .font(.system(size: 32, weight: .bold))

                    Text(statusMessage)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Progress bar
                VStack(spacing: 12) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .scaleEffect(y: 2)
                        .padding(.horizontal, 48)

                    Text("\(Int(progress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tips
                Text("Prospero is weaving the threads of your previous adventure into an epic new tale...")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            startSequelGeneration()
        }
    }

    // MARK: - Functions

    private func startSequelGeneration() {
        guard !isGenerating else { return }
        isGenerating = true

        Task {
            do {
                // Start generation
                generationState = .analyzing
                statusMessage = "Analyzing Book \(bookNumber - 1)..."
                await animateProgress(to: 0.2, duration: 2.0)

                // Call API to generate sequel
                let response = try await APIManager.shared.generateSequel(
                    storyId: book1Story.id,
                    userPreferences: userPreferences
                )

                generationState = .creatingBible
                statusMessage = "Creating story bible for Book \(bookNumber)..."
                await animateProgress(to: 0.4, duration: 2.0)

                // Extract Book 2 story from response
                let book2Id = response.book2.id
                let book2Title = response.book2.title

                // Create Story object (we'll need to fetch full details)
                let book2 = Story(
                    id: book2Id,
                    userId: book1Story.userId,
                    title: book2Title,
                    status: "generating",
                    premiseId: nil,
                    bibleId: nil,
                    generationProgress: nil,
                    createdAt: Date(),
                    chaptersGenerated: 0,
                    seriesId: response.book2.seriesId,
                    bookNumber: response.book2.bookNumber,
                    coverImageUrl: nil,
                    genre: nil,
                    description: nil
                )

                book2Story = book2

                generationState = .generatingChapters
                statusMessage = "Generating chapters 1-6..."
                await animateProgress(to: 0.6, duration: 3.0)

                // Poll for generation status
                try await pollGenerationStatus(storyId: book2Id)

                generationState = .complete
                statusMessage = "Book \(bookNumber) is ready!"
                await animateProgress(to: 1.0, duration: 1.0)

                // Wait a moment then complete
                try await Task.sleep(nanoseconds: 1_000_000_000)

                await MainActor.run {
                    onComplete(book2)
                }

            } catch {
                NSLog("❌ Sequel generation failed: \(error)")
                generationState = .error(error.localizedDescription)
                statusMessage = "Failed to generate sequel"
            }
        }
    }

    private func pollGenerationStatus(storyId: String) async throws {
        var isComplete = false
        var attempts = 0
        let maxAttempts = 60 // 5 minutes max

        while !isComplete && attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            let status = try await APIManager.shared.checkGenerationStatus(storyId: storyId)

            // Check if generation is complete by looking at current_step
            // Complete when step is awaiting_ or doesn't start with generating_
            if let progress = status.progress {
                let currentStep = progress.currentStep  // currentStep is String, not Optional
                if !currentStep.hasPrefix("generating_") {
                    isComplete = true
                }
            } else if status.status == "error" {
                throw NSError(domain: "SequelGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generation failed"])
            }

            // Update progress based on chapters available (initial batch is 3 chapters)
            let chapterProgress = Double(status.chaptersAvailable) / 3.0
            await animateProgress(to: 0.6 + (min(chapterProgress, 1.0) * 0.3), duration: 0.5)

            attempts += 1
        }

        if !isComplete {
            throw NSError(domain: "SequelGeneration", code: -2, userInfo: [NSLocalizedDescriptionKey: "Generation timeout"])
        }
    }

    private func animateProgress(to target: Double, duration: Double) async {
        let steps = 20
        let increment = (target - progress) / Double(steps)
        let stepDuration = duration / Double(steps)

        for _ in 0..<steps {
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            await MainActor.run {
                progress = min(progress + increment, target)
            }
        }
    }
}

#Preview {
    SequelGenerationView(
        book1Story: Story(
            id: "preview-story-1",
            userId: "preview-user",
            title: "The Dragon's Quest",
            status: "active",
            premiseId: nil,
            bibleId: nil,
            generationProgress: nil,
            createdAt: Date(),
            chaptersGenerated: 12,
            seriesId: nil,
            bookNumber: 1,
            coverImageUrl: nil,
            genre: "Fantasy",
            description: "An epic dragon adventure"
        ),
        bookNumber: 2,
        userPreferences: [:],
        onComplete: { book2 in
            print("Book 2 complete: \(book2.title)")
        }
    )
}
