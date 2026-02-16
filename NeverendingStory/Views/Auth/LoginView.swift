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
    @State private var showAgeGate = false
    @State private var birthMonth: Int? = nil
    @State private var birthYear: Int? = nil
    @State private var isMinor: Bool? = nil

    var body: some View {
        ZStack {
            // Dark magical background
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.1, blue: 0.4), // Purple
                    Color(red: 0.1, green: 0.15, blue: 0.35), // Blue
                    Color.black.opacity(0.9) // Dark base
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Branding
                VStack(spacing: 16) {
                    ZStack {
                        // Subtle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.purple.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 15)

                        Image("AppIconImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(color: .purple.opacity(0.5), radius: 15)
                    }

                    VStack(spacing: 8) {
                        Text("Mythweaver")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Where Stories Never End")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Email/Password Form
                VStack(spacing: 16) {
                    // Email field
                    TextField("", text: $email, prompt: Text("Email or username").foregroundColor(.white.opacity(0.5)))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    // Password field
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.white.opacity(0.5)))
                        .textContentType(isSignUpMode ? .newPassword : .password)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    // Sign In / Sign Up button
                    Button(action: handleEmailAuth) {
                        Text(isSignUpMode ? "Create Account" : "Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.3), radius: 8)
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((authManager.isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1.0)

                    // Toggle between Sign In / Sign Up
                    Button(action: {
                        if isSignUpMode {
                            // Switching from signup to signin - clear DOB data
                            isSignUpMode = false
                            birthMonth = nil
                            birthYear = nil
                            isMinor = nil
                        } else {
                            // Switching from signin to signup - show age gate first
                            showAgeGate = true
                        }
                    }) {
                        Text(isSignUpMode ? "Already have an account? Sign In" : "New here? Create Account")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.3))
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.3))
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
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(authManager.isLoading)
                    .opacity(authManager.isLoading ? 0.5 : 1.0)
                }
                .padding(.horizontal, 32)

                // Loading state
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                        .padding()
                }

                Spacer()

                // Privacy note
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAgeGate) {
            AgeGateView(onAgeVerified: { month, year, minor in
                // Age verified - save DOB and proceed to signup form
                birthMonth = month
                birthYear = year
                isMinor = minor
                showAgeGate = false
                isSignUpMode = true
            })
        }
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
                    // Create account
                    try await authManager.signUpWithEmail(email: email, password: password)

                    // After successful signup, save DOB to backend
                    if let month = birthMonth, let year = birthYear {
                        NSLog("📅 Saving DOB after account creation: \(month)/\(year)")
                        try await APIManager.shared.saveDOB(birthMonth: month, birthYear: year)
                        NSLog("✅ DOB saved successfully")
                    } else {
                        NSLog("⚠️ No DOB data to save (should not happen - age gate should have set this)")
                    }
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
