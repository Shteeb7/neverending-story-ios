//
//  LaunchView.swift
//  NeverendingStory
//
//  Initial launch screen with branded splash
//

import SwiftUI

struct LaunchView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showContent = false

    var body: some View {
        Group {
            if !showContent {
                // Splash screen
                VStack(spacing: 24) {
                    Spacer()

                    // App icon/logo (using SF Symbol as placeholder)
                    Image(systemName: "book.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Neverending Story")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Every page is a new adventure")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    ProgressView()
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // Navigate based on auth state and onboarding completion
                if authManager.isAuthenticated {
                    if authManager.user?.hasCompletedOnboarding == true {
                        LibraryView()
                    } else {
                        OnboardingView()
                    }
                } else {
                    LoginView()
                }
            }
        }
        .onAppear {
            // Wait for auth check, then show content with animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}

#Preview {
    LaunchView()
}
