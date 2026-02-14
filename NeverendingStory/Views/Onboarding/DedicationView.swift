//
//  DedicationView.swift
//  NeverendingStory
//
//  Dedication page shown once before Prospero interview
//

import SwiftUI

struct DedicationView: View {
    let onComplete: () -> Void

    @State private var firstLineOpacity = 0.0
    @State private var secondLineText = ""
    @State private var showTapPrompt = false
    @State private var canTap = false
    @State private var isFadingOut = false

    private let firstLine = "For Rob, Faith and Brady"
    private let secondLine = "See you in the wasteland"

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            // Dedication text
            VStack(spacing: 24) {
                // First line - the dedication (displayed immediately, fades in)
                Text(firstLine)
                    .font(.system(.title2, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(firstLineOpacity)

                // Second line - the poetic message (types out)
                Text(secondLineText)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.7))
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
            if canTap && !isFadingOut {
                fadeOut()
            }
        }
        .opacity(isFadingOut ? 0 : 1)
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        Task {
            // Fade in first line over 1 second
            await MainActor.run {
                withAnimation(.easeIn(duration: 1.0)) {
                    firstLineOpacity = 1.0
                }
            }

            // Wait for fade-in to complete, plus 1.5 second pause
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            // Type second line (70ms per character)
            for character in secondLine {
                await MainActor.run {
                    secondLineText.append(character)
                }
                try? await Task.sleep(nanoseconds: 70_000_000) // 70ms per character
            }

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

    private func fadeOut() {
        withAnimation(.easeOut(duration: 0.5)) {
            isFadingOut = true
        }

        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

#Preview {
    DedicationView {
        print("Dedication complete")
    }
}
