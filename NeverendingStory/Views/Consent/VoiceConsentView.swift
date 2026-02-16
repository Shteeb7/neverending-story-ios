import SwiftUI

struct VoiceConsentView: View {
    @Environment(\.dismiss) var dismiss

    @State private var isSubmitting = false
    @State private var error: String?

    var onConsent: () -> Void

    var body: some View {
        ZStack {
            // Dark mystical gradient background
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

                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                        .padding(.bottom, 8)

                    // Heading
                    Text("A Note About Voice")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Body text (legally required points in warm language)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("When you speak with Prospero, your voice is recorded to personalize your story experience.")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.9))

                        Text("Here's what you should know:")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 16) {
                            BulletPoint(text: "Your voice recordings are sent to third-party AI service providers for processing. Recordings are kept for one year after your story is generated, then automatically and permanently deleted.")

                            BulletPoint(text: "You can request early deletion at any time by emailing privacy@mythweaver.com.")

                            BulletPoint(text: "You can also revoke voice consent anytime in Settings, which will default you to text conversations and delete your stored recordings.")
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

                    // Two buttons: I Consent (primary) and Go Back (secondary)
                    VStack(spacing: 16) {
                        // Primary: I Consent
                        Button(action: grantVoiceConsent) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Text("I Consent")
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

                        // Secondary: Go Back
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Go Back")
                                .font(.system(size: 17))
                                .foregroundColor(Color.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func grantVoiceConsent() {
        guard !isSubmitting else { return }

        isSubmitting = true
        error = nil

        Task {
            do {
                try await APIManager.shared.grantVoiceConsent()

                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                    // Call the completion handler to proceed to voice interview
                    onConsent()
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

// Helper view for bullet points
struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))

            Text(text)
                .font(.system(size: 17))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }
}

#Preview {
    VoiceConsentView(onConsent: {
        print("Voice consent granted")
    })
}
