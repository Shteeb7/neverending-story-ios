//
//  BookCoverCard.swift
//  NeverendingStory
//
//  Book cover-style card for library
//

import SwiftUI

struct BookCoverCard: View {
    let story: Story
    var isSmall: Bool = false
    let action: () -> Void

    private var coverWidth: CGFloat { isSmall ? 140 : 180 }
    private var coverHeight: CGFloat { isSmall ? 210 : 270 }

    private var isReadable: Bool {
        if let progress = story.generationProgress {
            return progress.chaptersGenerated > 0
        }
        return true
    }

    private var readingProgress: Double {
        guard let progress = story.generationProgress else { return 0 }
        return Double(progress.chaptersGenerated) / 12.0
    }

    // Generate a gradient based on story title for variety (fallback when no cover)
    private var coverGradient: LinearGradient {
        let hash = abs(story.title.hashValue)
        let hueOptions: [Color] = [
            .blue, .purple, .indigo, .teal, .cyan, .mint
        ]
        let primary = hueOptions[hash % hueOptions.count]
        let secondary = hueOptions[(hash / 7) % hueOptions.count]

        return LinearGradient(
            colors: [primary.opacity(0.85), secondary.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: { if isReadable { action() } }) {
            ZStack(alignment: .bottom) {
                // Cover image or gradient fallback
                if let urlString = story.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: coverWidth, height: coverHeight)
                                .clipped()
                        case .failure:
                            gradientFallback
                        case .empty:
                            gradientPlaceholder
                        @unknown default:
                            gradientFallback
                        }
                    }
                    .frame(width: coverWidth, height: coverHeight)
                } else {
                    gradientFallback
                }

                // Generation overlay
                if story.isGenerating {
                    generatingOverlay
                }

                // Reading progress bar (non-small cards only, non-generating)
                if !isSmall && !story.isGenerating && readingProgress > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: geo.size.width * readingProgress, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: coverWidth, height: coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .opacity(isReadable ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isReadable)
    }

    // MARK: - Subviews

    private var gradientFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(coverGradient)
                .frame(width: coverWidth, height: coverHeight)

            VStack(spacing: 0) {
                Spacer()
                Text(story.title)
                    .font(isSmall ? .subheadline : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                Spacer()
            }
            .frame(width: coverWidth, height: coverHeight)
        }
    }

    private var gradientPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(coverGradient)
            .frame(width: coverWidth, height: coverHeight)
            .overlay(
                ProgressView()
                    .tint(.white.opacity(0.6))
            )
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)

            VStack(spacing: 8) {
                Spacer()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
                Text(story.progressText)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: coverWidth, height: coverHeight)
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            // Story with generated cover
            BookCoverCard(
                story: Story(
                    id: "1",
                    userId: "user1",
                    title: "The Last Archive",
                    status: "active",
                    premiseId: "premise1",
                    bibleId: "bible1",
                    generationProgress: GenerationProgress(
                        bibleComplete: true,
                        arcComplete: true,
                        chaptersGenerated: 6,
                        currentStep: "chapters_ready",
                        lastUpdated: Date().ISO8601Format()
                    ),
                    createdAt: Date(),
                    chaptersGenerated: nil,
                    seriesId: nil,
                    bookNumber: nil,
                    coverImageUrl: "https://placehold.co/180x270",
                    genre: "Sci-Fi",
                    description: "A futuristic tale"
                ),
                action: {}
            )

            // Story without cover (gradient fallback)
            BookCoverCard(
                story: Story(
                    id: "2",
                    userId: "user1",
                    title: "Echoes of Tomorrow",
                    status: "active",
                    premiseId: "premise2",
                    bibleId: "bible2",
                    generationProgress: GenerationProgress(
                        bibleComplete: true,
                        arcComplete: false,
                        chaptersGenerated: 3,
                        currentStep: "generating_chapters",
                        lastUpdated: Date().ISO8601Format()
                    ),
                    createdAt: Date(),
                    chaptersGenerated: nil,
                    seriesId: nil,
                    bookNumber: nil,
                    coverImageUrl: nil,
                    genre: "Fantasy",
                    description: "A test story"
                ),
                action: {}
            )

            // Story still generating
            BookCoverCard(
                story: Story(
                    id: "3",
                    userId: "user1",
                    title: "The Void Between Stars",
                    status: "active",
                    premiseId: "premise3",
                    bibleId: "bible3",
                    generationProgress: GenerationProgress(
                        bibleComplete: false,
                        arcComplete: false,
                        chaptersGenerated: 0,
                        currentStep: "generating_bible",
                        lastUpdated: Date().ISO8601Format()
                    ),
                    createdAt: Date(),
                    chaptersGenerated: nil,
                    seriesId: nil,
                    bookNumber: nil,
                    coverImageUrl: nil,
                    genre: "Mystery",
                    description: "A test story"
                ),
                action: {}
            )

            // Small card with cover
            BookCoverCard(
                story: Story(
                    id: "4",
                    userId: "user1",
                    title: "Journey to the Center",
                    status: "completed",
                    premiseId: "premise4",
                    bibleId: "bible4",
                    generationProgress: GenerationProgress(
                        bibleComplete: true,
                        arcComplete: true,
                        chaptersGenerated: 12,
                        currentStep: "complete",
                        lastUpdated: Date().ISO8601Format()
                    ),
                    createdAt: Date(),
                    chaptersGenerated: nil,
                    seriesId: nil,
                    bookNumber: nil,
                    coverImageUrl: "https://placehold.co/140x210",
                    genre: "Adventure",
                    description: "An epic journey"
                ),
                isSmall: true,
                action: {}
            )
        }
        .padding()
    }
}
