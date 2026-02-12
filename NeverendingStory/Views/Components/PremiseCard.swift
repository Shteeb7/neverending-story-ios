//
//  PremiseCard.swift
//  NeverendingStory
//
//  Reusable card for premise selection
//

import SwiftUI

struct PremiseCard: View {
    let premise: Premise
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                // Genre badge
                HStack {
                    Text(premise.genre.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .cornerRadius(8)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }

                // Title
                Text(premise.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description
                Text(premise.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.1), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        PremiseCard(
            premise: Premise(
                id: "1",
                title: "The Last Archive",
                genre: "Mystery",
                description: "In a world where memories can be stored and traded, you discover a hidden archive containing secrets that could unravel society.",
                generatedAt: Date()
            ),
            isSelected: false,
            action: {}
        )

        PremiseCard(
            premise: Premise(
                id: "2",
                title: "Echoes of Tomorrow",
                genre: "Sci-Fi",
                description: "You wake up with the ability to see 24 hours into the future, but every vision you have changes the timeline in unexpected ways.",
                generatedAt: Date()
            ),
            isSelected: true,
            action: {}
        )
    }
    .padding()
}
