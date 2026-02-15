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

    private var isReadable: Bool {
        // Story is readable if it has at least 1 chapter generated
        if let progress = story.generationProgress {
            return progress.chaptersGenerated > 0
        }
        // If no progress info, assume it's readable (older stories)
        return true
    }

    var body: some View {
        Button(action: {
            // Only trigger action if readable
            if isReadable {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Status badge
                HStack {
                    Text(story.status.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)

                    if !isReadable {
                        // Show "generating" indicator
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Writing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                // Title
                Text(story.title)
                    .font(isActive ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(isReadable ? .primary : .secondary)
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
            .background(isReadable ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
            .cornerRadius(16)
            .opacity(isReadable ? 1.0 : 0.7)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isReadable ? Color.clear : Color(.systemGray4), lineWidth: 1)
                    .opacity(isReadable ? 0 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isReadable)
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
                createdAt: Date(), chaptersGenerated: nil, seriesId: nil, bookNumber: nil
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
                createdAt: Date(), chaptersGenerated: nil, seriesId: nil, bookNumber: nil
            ),
            isActive: false,
            action: {}
        )
        .padding()
    }
}
