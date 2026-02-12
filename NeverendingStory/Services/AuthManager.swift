//
//  AuthManager.swift
//  NeverendingStory
//
//  Manages Supabase authentication
//

import Foundation
import Supabase
import Combine
import GoogleSignIn
import UIKit
import CryptoKit
import os.log

enum AuthError: LocalizedError {
    case noPresentingViewController
    case missingGoogleIDToken

    var errorDescription: String? {
        switch self {
        case .noPresentingViewController:
            return "Unable to present sign-in screen. Please try again."
        case .missingGoogleIDToken:
            return "Google sign-in did not return required credentials."
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var accessToken: String?

    @Published var user: User? {
        willSet {
            if newValue == nil && user != nil {
                NSLog("⚠️⚠️⚠️ USER BEING CLEARED!")
                NSLog("   Stack trace: %@", Thread.callStackSymbols.joined(separator: "\n"))
            }
        }
        didSet {
            NSLog("👤 USER CHANGED:")
            NSLog("   Old: %@", oldValue?.email ?? "nil")
            NSLog("   New: %@", user?.email ?? "nil")
            NSLog("   New ID: %@", user?.id ?? "NIL")

            if user == nil {
                // Force a UI update to show login
                Task { @MainActor in
                    self.objectWillChange.send()
                }
            }
        }
    }

    // Computed property - ONLY true if we have a valid user with ID
    var isAuthenticated: Bool {
        guard let user = user, !user.id.isEmpty else {
            return false
        }
        return true
    }
    @Published var isLoading = false

    private let supabase: SupabaseClient

    private var hasInitialized = false
    private var initTask: Task<Void, Never>?
    private var lastSignInTime: Date?

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        initTask = Task {
            // Only run initialization once
            guard !hasInitialized else { return }
            hasInitialized = true

            NSLog("🧹 First init - clearing any old sessions")
            do {
                try await supabase.auth.signOut(scope: .global)
                NSLog("✅ Old session cleared")
            } catch {
                NSLog("⚠️ Signout error: %@", error.localizedDescription)
            }

            await checkSession()
            initTask = nil // Clear reference when done
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        NSLog("🔍🔍🔍 checkSession() CALLED")

        // Skip if we just signed in (within last 5 seconds)
        if let lastSignIn = lastSignInTime, Date().timeIntervalSince(lastSignIn) < 5 {
            NSLog("⏭️ Skipping checkSession - just signed in \(Date().timeIntervalSince(lastSignIn))s ago")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            NSLog("🔍 Checking session...")

            // Try to refresh the session first - this validates it's still good
            let refreshedSession: Session
            do {
                refreshedSession = try await supabase.auth.refreshSession()
                NSLog("✅ Session refreshed successfully")
            } catch {
                NSLog("❌ Session refresh failed, signing out...")
                try? await supabase.auth.signOut()
                self.user = nil
                // isAuthenticated is now computed from user
                return
            }

            // Use the REFRESHED session data
            let supabaseUser = refreshedSession.user

            NSLog("✅ Session found!")
            NSLog("   User ID: %@", supabaseUser.id.uuidString)
            NSLog("   Email: %@", supabaseUser.email ?? "no email")

            // Convert Supabase user to our User model
            // Extract metadata values from AnyJSON
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

            let hasCompletedOnboardingValue: Bool = {
                if case let .bool(value) = supabaseUser.userMetadata["has_completed_onboarding"] {
                    return value
                }
                return false  // Default to false for new users
            }()

            let userId = supabaseUser.id.uuidString

            // CRITICAL: Ensure user ID is valid
            guard !userId.isEmpty, userId.count > 10 else {
                NSLog("❌ CRITICAL: Invalid user ID from checkSession: '%@'", userId)
                try? await supabase.auth.signOut()
                self.user = nil
                // isAuthenticated is now computed from user
                return
            }

            self.user = User(
                id: userId,
                email: supabaseUser.email,
                name: nameValue,
                avatarURL: avatarURLValue,
                createdAt: supabaseUser.createdAt,
                hasCompletedOnboarding: hasCompletedOnboardingValue
            )
            // Store the access token
            self.accessToken = refreshedSession.accessToken
            // isAuthenticated is now computed from user
            NSLog("✅✅✅ USER SET IN CHECK SESSION")
            NSLog("   ID: %@", userId)
            NSLog("   Email: %@", supabaseUser.email ?? "nil")
            NSLog("   Access token: %@...", String(refreshedSession.accessToken.prefix(20)))
        } catch {
            print("❌ checkSession error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // If session is invalid, sign out to clear corrupted state
            print("🧹 Clearing invalid session...")
            try? await supabase.auth.signOut()

            self.user = nil
            // isAuthenticated is now computed from user
        }
    }

    // MARK: - OAuth Authentication

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Generate raw nonce and hash it for Google
        let rawNonce = generateNonce()
        let hashedNonce = sha256(rawNonce)
        print("🔐 Generated nonce")
        print("   Raw: \(rawNonce.prefix(10))...")
        print("   Hashed: \(hashedNonce.prefix(10))...")

        // Step 2: Get root view controller for presenting Google Sign-In sheet
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.noPresentingViewController
        }

        // Step 3: Present native Google Sign-In UI with HASHED nonce
        print("🔐 Starting Google Sign-In with hashed nonce...")
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: [],
                nonce: hashedNonce  // Pass HASHED nonce to Google
            ) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let signInResult = signInResult {
                    continuation.resume(returning: signInResult)
                } else {
                    continuation.resume(throwing: AuthError.missingGoogleIDToken)
                }
            }
        }

        print("✅ Google Sign-In successful")
        print("📧 User email: \(result.user.profile?.email ?? "no email")")

        // Step 4: Extract ID token from Google result
        guard let idToken = result.user.idToken?.tokenString else {
            print("❌ Missing ID token")
            throw AuthError.missingGoogleIDToken
        }
        print("🎫 ID Token obtained (length: \(idToken.count))")

        // Step 5: Exchange Google ID token with Supabase using RAW nonce
        print("🔄 Exchanging token with Supabase...")
        print("📍 Supabase URL: \(AppConfig.supabaseURL)")
        print("🔑 Using anon key: \(AppConfig.supabaseAnonKey.prefix(20))...")
        print("🎫 Using raw nonce: \(rawNonce.prefix(10))...")

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    nonce: rawNonce  // Pass RAW nonce to Supabase
                )
            )
            print("✅ Supabase sign-in successful")
            print("✅ Session user ID: \(session.user.id)")
            print("✅ Session user email: \(session.user.email ?? "no email")")

            // Directly populate user from session instead of calling checkSession
            let nameValue: String? = {
                if case let .string(value) = session.user.userMetadata["name"] {
                    return value
                }
                return nil
            }()

            let avatarURLValue: String? = {
                if case let .string(value) = session.user.userMetadata["avatar_url"] {
                    return value
                }
                return nil
            }()

            let hasCompletedOnboardingValue: Bool = {
                if case let .bool(value) = session.user.userMetadata["has_completed_onboarding"] {
                    return value
                }
                return false  // Default to false for new users
            }()

            let userId = session.user.id.uuidString

            // CRITICAL: Ensure user ID is valid before proceeding
            guard !userId.isEmpty, userId.count > 10 else {
                fatalError("❌ CRITICAL: Invalid user ID from Supabase: '\(userId)'")
            }

            self.user = User(
                id: userId,
                email: session.user.email,
                name: nameValue,
                avatarURL: avatarURLValue,
                createdAt: session.user.createdAt,
                hasCompletedOnboarding: hasCompletedOnboardingValue
            )
            // Store the access token for API calls
            self.accessToken = session.accessToken
            // isAuthenticated is now computed from user

            // Mark that we just signed in successfully
            lastSignInTime = Date()

            NSLog("✅✅✅ USER CREATED IN GOOGLE SIGN-IN")
            NSLog("   ID: %@", userId)
            NSLog("   Email: %@", session.user.email ?? "nil")
            NSLog("   isAuthenticated: %@", self.isAuthenticated ? "true" : "false")
            NSLog("🔑 FULL ACCESS TOKEN FOR TESTING:")
            NSLog("%@", session.accessToken)
        } catch {
            print("❌ Supabase error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Generates a random nonce for OAuth security
    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Hashes a string using SHA-256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }

        try await supabase.auth.signInWithOAuth(
            provider: .apple,
            redirectTo: URL(string: "neverendingstory://auth/callback")
        )
    }

    // MARK: - OAuth Callback Handling

    func handleOAuthCallback(url: URL) async throws {
        try await supabase.auth.session(from: url)
        await checkSession()
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        try await supabase.auth.signOut()
        self.user = nil
        // isAuthenticated is now computed from user
    }
}
