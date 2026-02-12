//
//  StoryCard.swift
//  NeverendingStory
//
//  Reusable story card for library
//

import SwiftUI

struct StoryCard: View {
    let story: Story
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Status badge
                Text(story.status.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)

                // Title
                Text(story.title)
                    .font(isActive ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Progress
                Text(story.progressText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isActive {
                    // Continue reading button
                    HStack {
                        Spacer()
                        Text("Continue Reading")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                        Spacer()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        StoryCard(
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
                    chaptersGenerated: 3,
                    currentStep: "chapters_ready",
                    lastUpdated: Date().ISO8601Format()
                ),
                createdAt: Date()
            ),
            isActive: true,
            action: {}
        )
        .padding()

        StoryCard(
            story: Story(
                id: "2",
                userId: "user1",
                title: "Echoes of Tomorrow",
                status: "generating",
                premiseId: "premise2",
                bibleId: "bible2",
                generationProgress: GenerationProgress(
                    bibleComplete: true,
                    arcComplete: false,
                    chaptersGenerated: 0,
                    currentStep: "generating_chapters",
                    lastUpdated: Date().ISO8601Format()
                ),
                createdAt: Date()
            ),
            isActive: false,
            action: {}
        )
        .padding()
    }
}
