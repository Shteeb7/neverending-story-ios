//
//  DedicationView.swift
//  NeverendingStory
//
//  Dedication page shown once before Prospero interview
//

import SwiftUI

struct DedicationView: View {
    let onComplete: () -> Void

    @State private var firstLineText = ""
    @State private var secondLineText = ""
    @State private var showTapPrompt = false
    @State private var canTap = false
    @State private var isPageTurning = false

    private let firstLine = "For Rob, Faith and Brady"
    private let secondLine = "I'll meet you in the wasteland"

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            // Dedication text
            VStack(spacing: 36) {
                // First line - the dedication
                Text(firstLineText)
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Second line - the poetic message
                Text(secondLineText)
                    .font(.title3)
                    .italic()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            // Tap to continue prompt
            VStack {
                Spacer()
                if showTapPrompt {
                    Text("tap to continue")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                        .transition(.opacity)
                        .padding(.bottom, 60)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire view tappable
        .onTapGesture {
            if canTap && !isPageTurning {
                turnPage()
            }
        }
        .rotation3DEffect(
            .degrees(isPageTurning ? -90 : 0),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.5
        )
        .opacity(isPageTurning ? 0 : 1)
        .onAppear {
            startTypewriterAnimation()
        }
    }

    // MARK: - Animation

    private func startTypewriterAnimation() {
        Task {
            // 1 second of pure black silence
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Type first line (60ms per character)
            await typeText(firstLine, into: \.firstLineText)

            // 1.5 second pause between lines
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            // Type second line (60ms per character)
            await typeText(secondLine, into: \.secondLineText)

            // 2 seconds of stillness
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Show "tap to continue" prompt
            await MainActor.run {
                withAnimation(.easeIn(duration: 1.0)) {
                    showTapPrompt = true
                }
                canTap = true
            }
        }
    }

    private func typeText(_ text: String, into keyPath: WritableKeyPath<DedicationView, String>) async {
        for character in text {
            await MainActor.run {
                var view = self
                view[keyPath: keyPath].append(character)

                // Update the actual state
                if keyPath == \DedicationView.firstLineText {
                    firstLineText.append(character)
                } else if keyPath == \DedicationView.secondLineText {
                    secondLineText.append(character)
                }
            }
            try? await Task.sleep(nanoseconds: 60_000_000) // 60ms per character
        }
    }

    private func turnPage() {
        isPageTurning = true

        withAnimation(.easeInOut(duration: 0.8)) {
            // Page turn animation handled by rotation3DEffect
        }

        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onComplete()
        }
    }
}

#Preview {
    DedicationView {
        print("Dedication complete")
    }
}
