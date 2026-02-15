//
//  ProsperoCheckInView.swift
//  NeverendingStory
//
//  Created for Adaptive Reading Engine - Phase 2
//  Presents Prospero's 3-dimension check-in after chapters 2, 5, and 8
//

import SwiftUI

struct ProsperoCheckInView: View {
    let checkpoint: String // "chapter_2", "chapter_5", or "chapter_8"
    let protagonistName: String
    let onComplete: (String, String, String) -> Void // (pacing, tone, character)

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPacing: String? = nil
    @State private var selectedTone: String? = nil
    @State private var selectedCharacter: String? = nil
    @State private var showFarewell = false

    private var checkpointNumber: Int {
        switch checkpoint {
        case "chapter_2": return 1
        case "chapter_5": return 2
        case "chapter_8": return 3
        default: return 1
        }
    }

    private var greeting: String {
        switch checkpointNumber {
        case 1: return "What do you think so far?"
        case 2: return "We're halfway through! How did those last two chapters feel?"
        case 3: return "We're nearing the final act..."
        default: return "How's the story feeling?"
        }
    }

    private var farewell: String {
        switch checkpointNumber {
        case 1: return "You've given me much to consider. Continue reading — I'll be weaving the next chapters while you do."
        case 2: return "Wonderful insights. Keep reading — the next act is being crafted as we speak."
        case 3: return "The finale is being written. Enjoy what remains while I craft the conclusion."
        default: return "Thank you for your insights."
        }
    }

    private var allSelected: Bool {
        selectedPacing != nil && selectedTone != nil && selectedCharacter != nil
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showFarewell {
                farewellView
            } else {
                questionView
            }
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer().frame(height: 60)

                // Prospero avatar
                prosperoAvatar

                // Greeting
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Three dimension questions
                VStack(spacing: 32) {
                    pacingQuestion
                    toneQuestion
                    characterQuestion
                }
                .padding(.horizontal, 24)

                // Continue button (shown after all selections)
                if allSelected {
                    Button(action: { showFarewellMessage() }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer().frame(height: 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: allSelected)
    }

    // MARK: - Farewell View

    private var farewellView: some View {
        VStack(spacing: 40) {
            Spacer()

            // Prospero avatar
            prosperoAvatar

            // Farewell message
            Text(farewell)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.primary)

            Spacer()
        }
        .transition(.opacity)
        .onAppear {
            // Auto-dismiss after showing farewell
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                completeFeedback()
            }
        }
    }

    // MARK: - Prospero Avatar

    private var prosperoAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: .purple.opacity(0.4), radius: 30)
    }

    // MARK: - Dimension Questions

    private var pacingQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How's the rhythm?")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                DimensionButton(
                    title: "I'm hooked",
                    isSelected: selectedPacing == "hooked",
                    action: { selectedPacing = "hooked" }
                )

                DimensionButton(
                    title: "A little slow",
                    isSelected: selectedPacing == "slow",
                    action: { selectedPacing = "slow" }
                )

                DimensionButton(
                    title: "Almost too fast",
                    isSelected: selectedPacing == "fast",
                    action: { selectedPacing = "fast" }
                )
            }
        }
    }

    private var toneQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How's the mood landing?")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                DimensionButton(
                    title: "Just right",
                    isSelected: selectedTone == "right",
                    action: { selectedTone = "right" }
                )

                DimensionButton(
                    title: "Too serious",
                    isSelected: selectedTone == "serious",
                    action: { selectedTone = "serious" }
                )

                DimensionButton(
                    title: "Too light",
                    isSelected: selectedTone == "light",
                    action: { selectedTone = "light" }
                )
            }
        }
    }

    private var characterQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How are you feeling about \(protagonistName)?")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                DimensionButton(
                    title: "Love them",
                    isSelected: selectedCharacter == "love",
                    action: { selectedCharacter = "love" }
                )

                DimensionButton(
                    title: "Warming up",
                    isSelected: selectedCharacter == "warming",
                    action: { selectedCharacter = "warming" }
                )

                DimensionButton(
                    title: "Not clicking",
                    isSelected: selectedCharacter == "not_clicking",
                    action: { selectedCharacter = "not_clicking" }
                )
            }
        }
    }

    // MARK: - Actions

    private func showFarewellMessage() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showFarewell = true
        }
    }

    private func completeFeedback() {
        guard let pacing = selectedPacing,
              let tone = selectedTone,
              let character = selectedCharacter else {
            return
        }

        onComplete(pacing, tone, character)
        dismiss()
    }
}

// MARK: - Dimension Button Component

struct DimensionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ?
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color(uiColor: .systemGray6), Color(uiColor: .systemGray6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.clear : Color(uiColor: .systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ProsperoCheckInView(
        checkpoint: "chapter_2",
        protagonistName: "Kael",
        onComplete: { pacing, tone, character in
            print("Feedback: \(pacing), \(tone), \(character)")
        }
    )
}
