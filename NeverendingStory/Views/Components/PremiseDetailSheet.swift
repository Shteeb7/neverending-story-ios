//
//  PremiseDetailSheet.swift
//  NeverendingStory
//
//  Full premise detail modal with "Choose This Story" action
//

import SwiftUI

struct PremiseDetailSheet: View {
    let premise: Premise
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Drag indicator
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 6)
                    Spacer()
                }
                .padding(.top, 8)

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
                }

                // Title
                Text(premise.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                // Full description (no line limit)
                Text(premise.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 32)

                // Choose Another button (dismisses sheet)
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Choose Another")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                // Choose This Story button
                Button(action: {
                    dismiss()
                    // Delay slightly so dismiss animation completes first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSelect()
                    }
                }) {
                    HStack {
                        Text("Choose This Story")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden) // We have our own
    }
}

#Preview {
    PremiseDetailSheet(
        premise: Premise(
            id: "1",
            title: "The Last Archive",
            genre: "Mystery",
            description: "In a world where memories can be stored and traded like currency, you discover a hidden archive containing forbidden memories that could unravel the very fabric of society. As a memory curator, you must decide whether to expose the truth or protect the established order. Every choice you make will reshape not only your future, but the memories of everyone around you.",
            hook: "What if your memories weren't really yours?",
            themes: ["Mystery", "Technology", "Choice", "Identity"],
            ageRange: "adult",
            generatedAt: Date()
        )
    ) {
        print("Selected!")
    }
}
