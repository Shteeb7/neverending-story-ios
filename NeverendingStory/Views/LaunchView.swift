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

    /// Re-reads user metadata from a fresh Supabase session to fix stale JWT issues.
    /// If the JWT cached on-device has outdated hasCompletedOnboarding, this corrects it.
    @MainActor
    private func refreshUserMetadata() async {
        do {
            let refreshedSession = try await authManager.supabase.auth.refreshSession()
            let supabaseUser = refreshedSession.user

            let hasCompletedOnboardingValue: Bool = {
                if case let .bool(value) = supabaseUser.userMetadata["has_completed_onboarding"] {
                    return value
                }
                return false
            }()

            let nameValue: String? = {
                if case let .string(value) = supabaseUser.userMetadata["name"] {
                    return value
                }
                return nil
            }()

            let avatarURLValue: String? = {
                if case let .string(value) = supabaseUser.userMetadata["avatar_url"] {
                    return value
                }
                return nil
            }()

            // Only update if the refreshed value differs (avoids unnecessary SwiftUI re-renders)
            if authManager.user?.hasCompletedOnboarding != hasCompletedOnboardingValue {
                NSLog("🔄 Metadata refresh: hasCompletedOnboarding changed from %@ to %@",
                      authManager.user?.hasCompletedOnboarding == true ? "true" : "false",
                      hasCompletedOnboardingValue ? "true" : "false")

                authManager.user = User(
                    id: supabaseUser.id.uuidString,
                    email: supabaseUser.email,
                    name: nameValue,
                    avatarURL: avatarURLValue,
                    createdAt: supabaseUser.createdAt,
                    hasCompletedOnboarding: hasCompletedOnboardingValue
                )
                authManager.accessToken = refreshedSession.accessToken
            } else {
                NSLog("🔄 Metadata refresh: hasCompletedOnboarding already correct (%@)",
                      hasCompletedOnboardingValue ? "true" : "false")
            }
        } catch {
            NSLog("⚠️ Metadata refresh failed (non-blocking): \(error.localizedDescription)")
            // Non-blocking — don't gate the app on this
        }
    }

    private func checkConsentStatus() {
        guard !isCheckingConsent else { return }

        isCheckingConsent = true
        NSLog("🔒 Checking AI consent status...")

        Task {
            do {
                let status = try await APIManager.shared.getConsentStatus()

                // Refresh auth session to pick up latest user metadata from server
                // This prevents stale JWT data from routing users to onboarding incorrectly
                await refreshUserMetadata()

                await MainActor.run {
                    consentChecked = true
                    showAIConsent = !status.aiConsent
                    isCheckingConsent = false
                    NSLog("🔒 Consent status: AI=\(status.aiConsent), Voice=\(status.voiceConsent)")
                    NSLog("🔒 hasCompletedOnboarding: \(authManager.user?.hasCompletedOnboarding == true)")
                }

                // After consent check, recompute is_minor flag (Part C: Age Gate)
                recomputeIsMinor()
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

    /// Recomputes is_minor flag based on current age (Part C: Age Gate)
    /// Runs once per app launch after authentication
    private func recomputeIsMinor() {
        Task {
            guard let userId = authManager.user?.id else { return }

            do {
                // Fetch current user preferences
                guard let prefs = try await APIManager.shared.getUserPreferences(userId: userId),
                      let birthMonth = prefs["birth_month"] as? Int,
                      let birthYear = prefs["birth_year"] as? Int else {
                    // No DOB data (existing users from before age gate) - skip
                    NSLog("📅 No birth_month/birth_year found - skipping is_minor recomputation (existing user)")
                    return
                }

                // Calculate current age using conservative month/year approach
                let now = Date()
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: now)
                let currentMonth = calendar.component(.month, from: now)

                var age = currentYear - birthYear
                if currentMonth < birthMonth {
                    age -= 1
                }

                let shouldBeMinor = age < 18
                let currentIsMinor = prefs["is_minor"] as? Bool ?? false

                // Update if flag doesn't match reality (e.g., user turned 18)
                if shouldBeMinor != currentIsMinor {
                    NSLog("📅 Age recomputation: updating is_minor from \(currentIsMinor) to \(shouldBeMinor) (age: \(age))")
                    try await APIManager.shared.updateIsMinor(userId: userId, isMinor: shouldBeMinor)
                } else {
                    NSLog("📅 is_minor flag is correct (\(currentIsMinor)), no update needed (age: \(age))")
                }
            } catch {
                NSLog("⚠️ Failed to recompute is_minor: \(error.localizedDescription)")
                // Non-blocking - don't gate app on this
            }
        }
    }
}

#Preview {
    LaunchView()
}
