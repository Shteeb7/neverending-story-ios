import SwiftUI

struct AIConsentView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var isSubmitting = false
    @State private var error: String?

    // Static guard to prevent duplicate API calls from .onAppear
    private static var hasShown = false

    var body: some View {
        ZStack {
            // Dark mystical gradient background (matches Mythweaver aesthetic)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)

                    // Decorative crystal ball icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                        .padding(.bottom, 8)

                    // Heading (warm, not legalistic)
                    Text("Before Your Story Begins")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Body text (warm but legally precise)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("To craft your personalized stories, Mythweaver sends your interview responses, reading preferences, and feedback to third-party AI service providers for story generation and personalization.")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.9))

                        Text("Mythweaver also uses your interactions to improve its own storytelling systems, but does not share your data with AI providers for training their models.")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.9))

                        // Privacy Policy link
                        Button(action: openPrivacyPolicy) {
                            Text("You can learn more in our Privacy Policy.")
                                .font(.system(size: 17))
                                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                                .underline()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)

                    // Error message if consent fails
                    if let error = error {
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                        .frame(height: 40)

                    // Single prominent "I Agree" button
                    Button(action: grantConsent) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text("I Agree — Begin My Journey")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.4, blue: 0.9),
                                    Color(red: 0.7, green: 0.3, blue: 0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func openPrivacyPolicy() {
        // Open Privacy Policy in Safari
        if let url = URL(string: "https://www.mythweaver.app/privacy") {
            UIApplication.shared.open(url)
        }
    }

    private func grantConsent() {
        guard !isSubmitting else { return }

        isSubmitting = true
        error = nil

        Task {
            do {
                try await APIManager.shared.grantAIConsent()

                await MainActor.run {
                    isSubmitting = false
                    // Post notification to trigger consent re-check in LaunchView
                    NotificationCenter.default.post(name: NSNotification.Name("ConsentGranted"), object: nil)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    AIConsentView()
        .environmentObject(AuthManager.shared)
}
