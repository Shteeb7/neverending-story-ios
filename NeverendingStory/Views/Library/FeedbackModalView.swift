//
//  FeedbackModalView.swift
//  NeverendingStory
//
//  Quick feedback modal for when users exit mid-chapter
//

import SwiftUI

struct FeedbackModalView: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (String) -> Void

    private let feedbackOptions = [
        "Story got predictable",
        "Pacing issues",
        "Characters fell flat",
        "Plot didn't make sense",
        "Not the mood for this",
        "Just exploring, I'll be back"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)

                    Text("Quick feedback?")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Help us understand what's working and what's not")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)

                // Feedback options
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(feedbackOptions, id: \.self) { option in
                            FeedbackOptionButton(text: option) {
                                submitFeedback(option)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Skip button
                Button("Skip") {
                    dismiss()
                }
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func submitFeedback(_ feedback: String) {
        onSubmit(feedback)
        dismiss()
    }
}

// MARK: - Feedback Option Button

struct FeedbackOptionButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FeedbackModalView { feedback in
        print("Feedback: \(feedback)")
    }
}
