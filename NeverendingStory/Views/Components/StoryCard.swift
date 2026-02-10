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
                // Genre badge
                Text(story.genre.uppercased())
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.progressText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ProgressView(value: story.progress)
                        .tint(.accentColor)
                }

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
                genre: "Mystery",
                premise: "A mysterious archive holds secrets...",
                currentChapter: 3,
                totalChapters: 15,
                createdAt: Date(),
                updatedAt: Date(),
                isActive: true
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
                genre: "Sci-Fi",
                premise: "Time travel paradox...",
                currentChapter: 8,
                totalChapters: 12,
                createdAt: Date(),
                updatedAt: Date(),
                isActive: false
            ),
            isActive: false,
            action: {}
        )
        .padding()
    }
}
