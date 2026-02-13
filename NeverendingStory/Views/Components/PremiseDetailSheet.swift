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

                // Hook section (if exists)
                if let hook = premise.hook, !hook.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The Hook")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(hook)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Themes (if exist)
                if let themes = premise.themes, !themes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Themes")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(themes, id: \.self) { theme in
                                Text(theme)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(16)
                            }
                        }
                    }
                }

                Spacer(minLength: 32)

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

// MARK: - Flow Layout for Theme Tags

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(
                width: maxWidth,
                height: y + lineHeight
            )
        }
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
