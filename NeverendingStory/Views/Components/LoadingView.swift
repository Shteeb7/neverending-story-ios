//
//  LoadingView.swift
//  NeverendingStory
//
//  Elegant loading indicator
//

import SwiftUI

struct LoadingView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.primary)

            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView("Generating your stories...")
}
