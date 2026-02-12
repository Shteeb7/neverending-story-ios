//
//  LoginView.swift
//  NeverendingStory
//
//  Email/Password and Google authentication
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
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

            // Email/Password Form
            VStack(spacing: 16) {
                // Email field
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                // Password field
                SecureField("Password", text: $password)
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                // Sign In / Sign Up button
                Button(action: handleEmailAuth) {
                    Text(isSignUpMode ? "Create Account" : "Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)

                // Toggle between Sign In / Sign Up
                Button(action: { isSignUpMode.toggle() }) {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "New here? Create Account")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }

                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .padding(.vertical, 8)

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
            }
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

    private func handleEmailAuth() {
        Task {
            do {
                if isSignUpMode {
                    try await authManager.signUpWithEmail(email: email, password: password)
                } else {
                    try await authManager.signInWithEmail(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

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
}

#Preview {
    LoginView()
}
