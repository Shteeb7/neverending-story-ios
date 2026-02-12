//
//  FirstLineCeremonyView.swift
//  NeverendingStory
//
//  Typewriter reveal for the opening line of new stories
//

import SwiftUI
import UIKit

struct FirstLineCeremonyView: View {
    let firstLine: String
    let readerSettings: ReaderSettings
    let onComplete: () -> Void

    @State private var displayedText: String = ""
    @State private var characterIndex: Int = 0
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            // Blank background matching reader settings
            readerSettings.backgroundColor
                .ignoresSafeArea()

            // Centered first line text with typewriter animation
            Text(displayedText)
                .font(.system(
                    size: readerSettings.fontSize,
                    weight: .regular,
                    design: readerSettings.fontDesign
                ))
                .lineSpacing(readerSettings.lineSpacing)
                .foregroundColor(readerSettings.textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .onAppear {
            // Prepare haptic generator for responsive feedback
            hapticGenerator.prepare()

            // Start ceremony after brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                animateNextCharacter()
            }
        }
    }

    private func animateNextCharacter() {
        guard characterIndex < firstLine.count else {
            // Animation complete - wait 500ms then call onComplete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
            return
        }

        // Add next character to displayed text
        let currentChar = firstLine[firstLine.index(firstLine.startIndex, offsetBy: characterIndex)]
        displayedText.append(currentChar)

        // Trigger haptic feedback every 3rd character
        if characterIndex % 3 == 0 {
            hapticGenerator.impactOccurred()
        }

        characterIndex += 1

        // Calculate variable delay for next character
        let baseDelay: Double = 0.040 // 40ms
        let randomVariation = Double.random(in: -0.015...0.015) // ±15ms
        var delay = baseDelay + randomVariation

        // Add extra pause after punctuation
        let punctuationSet: Set<Character> = [".", ",", ";", ":", "!", "?", "—"]
        if punctuationSet.contains(currentChar) {
            delay += 0.120 // Add 120ms pause
        }

        // Schedule next character
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateNextCharacter()
        }
    }
}

// MARK: - Helper Functions

extension FirstLineCeremonyView {
    /// Extracts the first line from chapter content
    /// Takes everything up to first newline or 150 characters, whichever comes first
    /// If longer than 150 chars, truncates to last complete word before 150
    static func extractFirstLine(from content: String) -> String {
        // Find first newline
        if let newlineIndex = content.firstIndex(of: "\n") {
            let lineToNewline = String(content[..<newlineIndex])

            // If line before newline is <= 150 chars, use it
            if lineToNewline.count <= 150 {
                return lineToNewline.trimmingCharacters(in: .whitespaces)
            }
        }

        // No newline within first 150 chars (or entire text)
        // Take first 150 characters
        if content.count <= 150 {
            return content.trimmingCharacters(in: .whitespaces)
        }

        // Truncate to 150 chars at word boundary
        let truncated = String(content.prefix(150))

        // Find last space to avoid cutting mid-word
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]).trimmingCharacters(in: .whitespaces)
        }

        // No spaces found (unlikely) - just return truncated
        return truncated.trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    FirstLineCeremonyView(
        firstLine: "The station's lights flickered once, then twice, before settling into an uneasy glow.",
        readerSettings: ReaderSettings.shared,
        onComplete: {
            print("Ceremony complete")
        }
    )
}
