//
//  VersionIndicator.swift
//  NeverendingStory
//
//  Small, discreet version and build number indicator
//

import SwiftUI

struct VersionIndicator: View {
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    var body: some View {
        Text(versionString)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
    }
}

#Preview {
    ZStack {
        Color.black
        VersionIndicator()
    }
}
