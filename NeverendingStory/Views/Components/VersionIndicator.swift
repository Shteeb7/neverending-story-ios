//
//  VersionIndicator.swift
//  NeverendingStory
//
//  Small, discreet version and build number indicator
//  Visible on all screens with adaptive styling for light/dark backgrounds
//

import SwiftUI

struct VersionIndicator: View {
    @Environment(\.colorScheme) var colorScheme

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    var body: some View {
        Text(versionString)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.primary.opacity(0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                // Semi-transparent background that adapts to color scheme
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// Global version overlay that appears at the bottom center of all screens
struct GlobalVersionOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VersionIndicator()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .ignoresSafeArea(.all, edges: .bottom)
        .allowsHitTesting(false) // Don't block touches on underlying content
    }
}

#Preview {
    ZStack {
        Color.black
        VersionIndicator()
    }
}
