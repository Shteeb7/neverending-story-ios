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

    // Generate a gradient based on story title for variety
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
            ZStack {
                // Book cover background
                RoundedRectangle(cornerRadius: 12)
                    .fill(coverGradient)
                    .frame(width: coverWidth, height: coverHeight)

                VStack(spacing: 0) {
                    Spacer()

                    // Title
                    Text(story.title)
                        .font(isSmall ? .subheadline : .headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 16)

                    Spacer()

                    // Progress / status at bottom
                    VStack(spacing: 4) {
                        if story.isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        }
                        Text(story.progressText)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: coverWidth, height: coverHeight)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .opacity(isReadable ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isReadable)
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
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
                    bookNumber: nil
                ),
                action: {}
            )

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
                    bookNumber: nil
                ),
                action: {}
            )

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
                    bookNumber: nil
                ),
                action: {}
            )

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
                    bookNumber: nil
                ),
                isSmall: true,
                action: {}
            )
        }
        .padding()
    }
}
