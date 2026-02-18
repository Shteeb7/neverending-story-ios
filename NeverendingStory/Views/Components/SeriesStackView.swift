//
//  SeriesStackView.swift
//  NeverendingStory
//
//  Stacked card visual for book series - collapses to show front card with others peeking behind,
//  expands on tap to show all books in the series
//

import SwiftUI

struct SeriesStackView: View {
    let seriesName: String
    let books: [Story]
    let onSelectBook: (Story) -> Void

    @State private var isExpanded = false

    private var sortedBooks: [Story] {
        books.sorted { ($0.bookNumber ?? 0) < ($1.bookNumber ?? 0) }
    }

    private var frontBook: Story {
        // Show the first unread book, or the latest book if all read
        sortedBooks.last ?? books[0]
    }

    private var readCount: Int {
        // Count books that have all 12 chapters
        books.filter { ($0.chaptersGenerated ?? 0) >= 12 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: - Collapsed State

    private var collapsedView: some View {
        VStack(alignment: .center, spacing: 8) {
            // Stacked cards
            ZStack {
                // Background cards peeking out
                ForEach(0..<min(2, books.count - 1), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.15, green: 0.1, blue: 0.2))
                        .frame(width: 160, height: 240)
                        .offset(x: CGFloat((index + 1) * 4), y: CGFloat((index + 1) * 4))
                        .scaleEffect(1.0 - CGFloat(index + 1) * 0.03)
                        .opacity(0.6)
                }

                // Front card
                frontBookCard
            }
            .onTapGesture {
                isExpanded = true
            }

            // Series info
            VStack(spacing: 4) {
                Text("\(seriesName) Series")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(.white)

                Text("\(readCount) of \(books.count) read")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var frontBookCard: some View {
        ZStack(alignment: .topTrailing) {
            // Cover image
            if let coverUrl = frontBook.coverImageUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 240)
                            .clipped()
                            .cornerRadius(12)
                    case .failure(_), .empty:
                        placeholderCover
                    @unknown default:
                        placeholderCover
                    }
                }
            } else {
                placeholderCover
            }

            // Series badge
            if let bookNumber = frontBook.bookNumber {
                SeriesBadgeView(bookNumber: bookNumber, totalBooks: books.count)
                    .padding(8)
            }

            // "Being Conjured" overlay if generating
            if frontBook.isGenerating {
                ZStack {
                    Color.black.opacity(0.7)

                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Being Conjured")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .cornerRadius(12)
            }
        }
        .frame(width: 160, height: 240)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.5),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 160, height: 240)
            .overlay(
                Image(systemName: "book.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
            )
    }

    // MARK: - Expanded State

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with series name and collapse button
            HStack {
                Text("\(seriesName) Series")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { isExpanded = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // All books in horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(sortedBooks) { book in
                        bookCardExpanded(book)
                            .onTapGesture {
                                if !book.isGenerating {
                                    onSelectBook(book)
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.05, blue: 0.15).opacity(0.9))
        )
    }

    private func bookCardExpanded(_ book: Story) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Cover
                if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 180)
                                .clipped()
                                .cornerRadius(8)
                        case .failure(_), .empty:
                            expandedPlaceholder
                        @unknown default:
                            expandedPlaceholder
                        }
                    }
                } else {
                    expandedPlaceholder
                }

                // Badge
                if let bookNumber = book.bookNumber {
                    SeriesBadgeView(bookNumber: bookNumber, totalBooks: books.count)
                        .padding(6)
                }

                // Generating overlay
                if book.isGenerating {
                    ZStack {
                        Color.black.opacity(0.7)
                        VStack(spacing: 6) {
                            ProgressView()
                                .tint(.white)
                            Text("Conjuring")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 120, height: 180)
                    .cornerRadius(8)
                }
            }
            .frame(width: 120, height: 180)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

            // Title
            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 120)
        }
    }

    private var expandedPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.5),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 120, height: 180)
            .overlay(
                Image(systemName: "book.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

#Preview {
    SeriesStackView(
        seriesName: "The Whisper of the Webs",
        books: [
            Story(
                id: "1",
                userId: "user1",
                title: "Book One",
                status: "active",
                premiseId: nil,
                bibleId: nil,
                generationProgress: nil,
                createdAt: Date(),
                chaptersGenerated: 12,
                seriesId: "series1",
                bookNumber: 1,
                coverImageUrl: nil,
                genre: "Fantasy",
                description: nil,
                seriesName: "The Whisper of the Webs"
            ),
            Story(
                id: "2",
                userId: "user1",
                title: "Book Two",
                status: "active",
                premiseId: nil,
                bibleId: nil,
                generationProgress: nil,
                createdAt: Date(),
                chaptersGenerated: 12,
                seriesId: "series1",
                bookNumber: 2,
                coverImageUrl: nil,
                genre: "Fantasy",
                description: nil,
                seriesName: "The Whisper of the Webs"
            )
        ],
        onSelectBook: { _ in }
    )
    .padding()
    .background(Color.black)
}
