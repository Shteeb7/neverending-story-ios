//
//  LoadingView.swift
//  NeverendingStory
//
//  Magical loading experience with floating sparkles and mystical animations
//

import SwiftUI

struct LoadingView: View {
    let message: String

    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkleOpacity: Double = 0.3

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // Floating sparkles background
            ForEach(0..<20, id: \.self) { index in
                FloatingSparkle(index: index, isAnimating: isAnimating)
            }

            VStack(spacing: 40) {
                // Magical center orb with rotating rings
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(rotationAngle))

                    // Middle pulsing glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.4),
                                    Color.blue.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                        .opacity(sparkleOpacity)

                    // Inner rotating ring (counter-clockwise)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.4),
                                    Color.cyan.opacity(0.4),
                                    Color.blue.opacity(0.4)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-rotationAngle * 1.5))

                    // Center magical orb
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.purple,
                                        Color.blue,
                                        Color.cyan
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.purple.opacity(0.6), radius: 20, x: 0, y: 0)

                        // Sparkle icon
                        Image(systemName: "sparkles")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse)
                    }

                    // Orbiting particles
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 8, height: 8)
                            .offset(x: 90)
                            .rotationEffect(.degrees(rotationAngle * 2 + Double(index * 120)))
                            .shadow(color: Color.yellow.opacity(0.8), radius: 4)
                    }
                }

                // Message text with magical styling
                Text(message)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            // Start all animations
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }

            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                sparkleOpacity = 0.8
            }

            isAnimating = true
        }
    }
}

// Floating sparkle particle
struct FloatingSparkle: View {
    let index: Int
    let isAnimating: Bool

    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: CGFloat.random(in: 8...20)))
            .foregroundColor(randomColor())
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                // Random starting position
                xOffset = CGFloat.random(in: -150...150)
                yOffset = CGFloat.random(in: -300...300)

                // Random delay for staggered animation
                let delay = Double.random(in: 0...2)

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Fade in
                    withAnimation(.easeIn(duration: 1)) {
                        opacity = Double.random(in: 0.3...0.7)
                    }

                    // Gentle float animation
                    withAnimation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                    ) {
                        yOffset += CGFloat.random(in: -50...50)
                        xOffset += CGFloat.random(in: -30...30)
                    }

                    // Gentle rotation
                    withAnimation(
                        .linear(duration: Double.random(in: 4...8))
                        .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }
            }
    }

    private func randomColor() -> Color {
        let colors: [Color] = [.purple, .blue, .cyan, .pink, .yellow]
        return colors[index % colors.count]
    }
}

#Preview {
    LoadingView("Generating your stories...")
}
