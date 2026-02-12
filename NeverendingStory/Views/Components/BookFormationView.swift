//
//  BookFormationView.swift
//  NeverendingStory
//
//  Magical book formation animation with flying symbols being absorbed
//

import SwiftUI

struct BookFormationView: View {
    @State private var isAnimating = false
    @State private var bookScale: CGFloat = 0.8
    @State private var bookGlow: Double = 0.3

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // Flying symbols being absorbed by the book
            ForEach(0..<15, id: \.self) { index in
                FlyingSymbol(index: index, isAnimating: isAnimating)
            }

            VStack(spacing: 40) {
                // Central magical book with glow
                ZStack {
                    // Outer magical aura
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(bookGlow),
                                    Color.purple.opacity(bookGlow * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(bookScale)

                    // Rotating energy ring
                    ForEach(0..<3, id: \.self) { ringIndex in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.3),
                                        Color.cyan.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(140 + ringIndex * 30), height: CGFloat(140 + ringIndex * 30))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                .linear(duration: Double(3 + ringIndex))
                                .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    }

                    // The book icon
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse)
                        .shadow(color: Color.blue.opacity(0.8), radius: 20, x: 0, y: 0)
                        .scaleEffect(bookScale)

                    // Sparkles appearing around the book
                    ForEach(0..<6, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                            .offset(x: 60)
                            .rotationEffect(.degrees(Double(index * 60)))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .opacity(bookGlow)
                            .animation(
                                .linear(duration: 4)
                                .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    }
                }

                // Message text
                VStack(spacing: 16) {
                    Text("Ok reader, we are now writing your entire book.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    Text("Think you can wait about 10 minutes?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Feel free to go get a cup of tea and come on back ☕")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(bookGlow + 0.3)
                }
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            isAnimating = true

            // Pulsing book animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bookScale = 1.1
            }

            // Pulsing glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bookGlow = 0.8
            }
        }
    }
}

// Flying symbol that gets absorbed by the book
struct FlyingSymbol: View {
    let index: Int
    let isAnimating: Bool

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    // Story-related symbols
    private let symbols = [
        "character.book.closed", "pencil.and.outline", "character.cursor.ibeam",
        "crown.fill", "shield.fill", "bolt.fill", "sparkles", "wand.and.stars",
        "moon.stars.fill", "star.fill", "heart.fill", "flame.fill",
        "figure.walk", "flag.fill", "key.fill"
    ]

    var body: some View {
        Image(systemName: symbols[index % symbols.count])
            .font(.system(size: CGFloat.random(in: 20...35)))
            .foregroundStyle(
                LinearGradient(
                    colors: randomGradient(),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(opacity)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .shadow(color: randomColor().opacity(0.6), radius: 8)
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        // Random starting position from edges of screen
        let startPositions: [(x: CGFloat, y: CGFloat)] = [
            (-50, CGFloat.random(in: 200...800)),  // Left edge
            (450, CGFloat.random(in: 200...800)),  // Right edge
            (CGFloat.random(in: 50...350), -50),   // Top edge
            (CGFloat.random(in: 50...350), 900)    // Bottom edge
        ]

        let startPos = startPositions[index % 4]
        position = CGPoint(x: startPos.x, y: startPos.y)

        // Stagger the animations
        let delay = Double.random(in: 0...3)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Fade in
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
            }

            // Fly toward center and get absorbed
            withAnimation(.easeInOut(duration: Double.random(in: 2...4))) {
                position = CGPoint(x: 200, y: 400) // Center of book
                scale = 0.1 // Shrink as it gets absorbed
                rotation = Double.random(in: 180...720) // Spin while flying
            }

            // Fade out as it gets absorbed
            withAnimation(.easeOut(duration: 1).delay(1.5)) {
                opacity = 0
            }

            // Restart animation after absorption
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                // Reset and repeat
                position = CGPoint(x: startPos.x, y: startPos.y)
                scale = 1.0
                opacity = 0
                rotation = 0
                startAnimation()
            }
        }
    }

    private func randomColor() -> Color {
        let colors: [Color] = [.blue, .purple, .cyan, .pink, .yellow, .orange, .green]
        return colors[index % colors.count]
    }

    private func randomGradient() -> [Color] {
        let gradients: [[Color]] = [
            [.blue, .cyan],
            [.purple, .pink],
            [.yellow, .orange],
            [.green, .cyan],
            [.red, .pink],
            [.blue, .purple]
        ]
        return gradients[index % gradients.count]
    }
}

#Preview {
    BookFormationView()
}
