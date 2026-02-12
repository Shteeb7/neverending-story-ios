//
//  LoginView.swift
//  NeverendingStory
//
//  OAuth authentication view
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Branding
            VStack(spacing: 16) {
                Image(systemName: "book.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Neverending Story")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("AI-powered books that never end")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            // Authentication buttons
            VStack(spacing: 16) {
                // Google Sign In
                Button(action: signInWithGoogle) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.title3)

                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .disabled(authManager.isLoading)

                // Apple Sign In
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .frame(maxWidth: 375) // Prevent constraint conflict on wide screens
                .cornerRadius(12)
                .disabled(authManager.isLoading)
            }
            .frame(maxWidth: .infinity) // Center the VStack
            .padding(.horizontal, 32)

            // Loading state
            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
            }

            Spacer()

            // Privacy note
            Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        // The actual token handling would need to be implemented
                        // This is a placeholder structure
                        print("Apple Sign In successful: \(appleIDCredential.user)")

                        // In a real implementation, you would:
                        // 1. Get the identity token and authorization code
                        // 2. Send to your backend via APIManager
                        // 3. Backend validates with Apple and creates/updates user
                        // 4. Returns session token to client

                        try await authManager.signInWithApple()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    LoginView()
}
