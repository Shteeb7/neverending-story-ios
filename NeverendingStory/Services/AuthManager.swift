//
//  AuthManager.swift
//  NeverendingStory
//
//  Manages Supabase authentication
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private let supabase: SupabaseClient

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
            supabaseKey: AppConfig.supabaseAnonKey
        )

        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.session
            let supabaseUser = session.user

            // Convert Supabase user to our User model
            self.user = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                name: supabaseUser.userMetadata["name"] as? String,
                avatarURL: supabaseUser.userMetadata["avatar_url"] as? String,
                createdAt: supabaseUser.createdAt
            )
            self.isAuthenticated = true
        } catch {
            self.user = nil
            self.isAuthenticated = false
        }
    }

    // MARK: - OAuth Authentication

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        // Note: This requires proper OAuth URL scheme configuration in Info.plist
        // The actual flow will open Safari/ASWebAuthenticationSession
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "neverendingstory://auth/callback")
        )
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
        self.isAuthenticated = false
    }
}
