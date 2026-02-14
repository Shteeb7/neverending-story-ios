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
    @State private var showDedication = false
    @AppStorage("hasSeenDedication") private var hasSeenDedication = false

    var body: some View {
        Group {
            if !showContent {
                // Splash screen
                ZStack {
                    // Dark magical background
                    RadialGradient(
                        colors: [
                            Color(red: 0.1, green: 0.05, blue: 0.2), // Deep navy center
                            Color.black.opacity(0.95) // Near-black edges
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 600
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Spacer()

                        // Actual app icon with glow
                        ZStack {
                            // Pulsing glow effect
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
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .blur(radius: 20)

                            Image("AppIconImage")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .shadow(color: .purple.opacity(0.5), radius: 20)

                            // Sparkle particles
                            Image(systemName: "sparkle")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                                .offset(x: -50, y: -50)

                            Image(systemName: "sparkle")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.6))
                                .offset(x: 60, y: -40)

                            Image(systemName: "sparkle")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.7))
                                .offset(x: -55, y: 55)
                        }

                        VStack(spacing: 8) {
                            Text("Mythweaver")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Where Stories Never End")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Navigate based on auth state and onboarding completion
                if authManager.isAuthenticated {
                    if authManager.user?.hasCompletedOnboarding == true {
                        LibraryView()
                    } else {
                        // Show dedication page once before onboarding
                        if !hasSeenDedication && !showDedication {
                            DedicationView {
                                hasSeenDedication = true
                                showDedication = true
                            }
                        } else {
                            OnboardingView()
                        }
                    }
                } else {
                    LoginView()
                }
            }
        }
        .onAppear {
            // TEST: Verify console works
            NSLog("🚀 LaunchView appeared - CONSOLE TEST")
            print("🚀 LaunchView appeared - PRINT TEST")

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
