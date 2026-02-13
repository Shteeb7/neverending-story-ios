//
//  BookCompleteView.swift
//  NeverendingStory
//
//  Congratulations screen after completing a book with sequel generation option
//

import SwiftUI

struct BookCompleteView: View {
    let story: Story
    let bookNumber: Int
    let onStartSequel: () -> Void
    let onReturnToLibrary: () -> Void

    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.4), Color.indigo.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Celebration icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.4),
                                    Color.orange.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(showConfetti ? 1.1 : 1.0)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(showConfetti ? 5 : -5))
                }
                .shadow(color: .orange.opacity(0.5), radius: 30)

                // Title
                VStack(spacing: 16) {
                    Text("Book \(bookNumber) Complete!")
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(story.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Description
                Text("You've completed an incredible journey! Prospero has heard what you loved and is ready to conjure Book \(bookNumber + 1) with even more of what you enjoyed.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    // Start sequel button
                    Button(action: { onStartSequel() }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title3)
                            Text("Start Book \(bookNumber + 1)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
                    }

                    // Return to library button
                    Button(action: { onReturnToLibrary() }) {
                        Text("Return to Library")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    BookCompleteView(
        story: Story(
            id: "preview-story",
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
        bookNumber: 1,
        onStartSequel: {
            print("Starting Book 2")
        },
        onReturnToLibrary: {
            print("Returning to library")
        }
    )
}
