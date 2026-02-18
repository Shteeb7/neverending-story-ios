//
//  BookCompleteView.swift
//  NeverendingStory
//
//  Magical "Conjure the Sequel" moment - the reader just finished a personalized novel
//

import SwiftUI

struct BookCompleteView: View {
    let story: Story
    let bookNumber: Int
    let onStartSequel: () -> Void
    let onReturnToLibrary: () -> Void

    @State private var showCover = false
    @State private var showTitle = false
    @State private var showLabel = false
    @State private var showButton = false
    @State private var hueAngle: Double = 0
    @State private var buttonScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dark magical background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),   // Deep purple
                    Color(red: 0.05, green: 0.05, blue: 0.15), // Dark blue-purple
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating particles
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    ParticleView(index: index, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Story cover image
                if let coverUrl = story.coverImageUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 300)
                                .cornerRadius(12)
                                .shadow(color: Color.white.opacity(0.3), radius: 20, x: 0, y: 0)
                        case .failure(_), .empty:
                            Image(systemName: "sparkles")
                                .font(.system(size: 80))
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .opacity(showCover ? 1 : 0)
                    .offset(y: showCover ? 0 : 20)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                        .opacity(showCover ? 1 : 0)
                        .offset(y: showCover ? 0 : 20)
                }

                // Story title
                Text(story.title)
                    .font(.custom("Georgia", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                // Book complete label
                Text("Book \(bookNumber) Complete")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                    .opacity(showLabel ? 1 : 0)
                    .offset(y: showLabel ? 0 : 20)

                Spacer()

                // Conjure Sequel button
                Button(action: {
                    // Brief burst animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onStartSequel()
                    }
                }) {
                    ZStack {
                        // Rainbow border
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        .red, .orange, .yellow, .green, .blue, .purple, .red
                                    ]),
                                    center: .center
                                )
                            )
                            .hueRotation(Angle(degrees: hueAngle))
                            .frame(height: 64)

                        // Button content
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                            Text("Conjure the Sequel")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(13)
                    }
                    .frame(height: 64)
                }
                .padding(.horizontal, 40)
                .scaleEffect(showButton ? buttonScale : 0.8)
                .opacity(showButton ? 1 : 0)

                // Return to Library button
                Button(action: onReturnToLibrary) {
                    VStack(spacing: 4) {
                        Text("Return to Library")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                        Text("You can always conjure a sequel later")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
            }
        }
        .onAppear {
            // Staggered entrance animations
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showCover = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                showLabel = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.2)) {
                showButton = true
            }

            // Rainbow border animation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                hueAngle = 360
            }

            // Pulsing button animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1.5)) {
                buttonScale = 1.03
            }
        }
    }
}

// Floating particle effect
struct ParticleView: View {
    let index: Int
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0

    private let randomX: CGFloat
    private let randomSize: CGFloat

    init(index: Int, screenWidth: CGFloat, screenHeight: CGFloat) {
        self.index = index
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.randomX = CGFloat.random(in: 0...screenWidth)
        self.randomSize = CGFloat.random(in: 2...6)
    }

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: randomSize, height: randomSize)
            .opacity(opacity)
            .position(
                x: randomX,
                y: screenHeight + yOffset
            )
            .onAppear {
                let duration = Double.random(in: 3...6)
                let delay = Double.random(in: 0...2)

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false).delay(delay)) {
                    yOffset = -screenHeight - 100
                }

                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(delay)) {
                    opacity = Double.random(in: 0.3...0.8)
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
            description: "An epic dragon adventure",
            seriesName: nil
        ),
        bookNumber: 1,
        onStartSequel: {},
        onReturnToLibrary: {}
    )
}
