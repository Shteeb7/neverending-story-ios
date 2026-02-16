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
    @State private var showAIConsent = false
    @State private var isCheckingConsent = false
    @State private var consentChecked = false
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

                    // Version indicator in top left corner
                    VStack {
                        HStack {
                            VersionIndicator()
                                .padding(.leading, 16)
                                .padding(.top, 16)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Navigate based on auth state, consent, and onboarding completion
                if authManager.isAuthenticated {
                    // Check AI consent before proceeding
                    if !consentChecked {
                        // Checking consent status...
                        ZStack {
                            Color.black.ignoresSafeArea()
                            ProgressView()
                                .tint(.white)
                        }
                    } else if showAIConsent {
                        // User needs to consent to AI usage
                        AIConsentView()
                    } else {
                        // Consent granted, proceed normally
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
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && !isCheckingConsent && !consentChecked {
                // User just authenticated, check consent status
                checkConsentStatus()
            }
        }
        .onChange(of: showContent) { _, newValue in
            if newValue && authManager.isAuthenticated && !isCheckingConsent && !consentChecked {
                // Content shown and user is authenticated, check consent
                checkConsentStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConsentGranted"))) { _ in
            // Consent was granted, re-check status
            NSLog("🔒 Consent granted notification received, re-checking status...")
            consentChecked = false
            checkConsentStatus()
        }
    }

    private func checkConsentStatus() {
        guard !isCheckingConsent else { return }

        isCheckingConsent = true
        NSLog("🔒 Checking AI consent status...")

        Task {
            do {
                let status = try await APIManager.shared.getConsentStatus()
                await MainActor.run {
                    consentChecked = true
                    showAIConsent = !status.aiConsent
                    isCheckingConsent = false
                    NSLog("🔒 Consent status: AI=\(status.aiConsent), Voice=\(status.voiceConsent)")
                }
            } catch {
                await MainActor.run {
                    // On error, assume consent is needed (safe default)
                    consentChecked = true
                    showAIConsent = true
                    isCheckingConsent = false
                    NSLog("❌ Failed to check consent status: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    LaunchView()
}
