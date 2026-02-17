//
//  BugReportVoiceView.swift
//  NeverendingStory
//
//  Voice interview wrapper for Peggy bug reporting
//

import SwiftUI
import AVFoundation

struct BugReportVoiceView: View {
    let reportType: BugReportView.ReportOption
    let capturedScreenshot: UIImage?
    let capturedMetadata: [String: Any]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceSession = VoiceSessionManager()
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSessionActive = false
    @State private var collectedData: [String: Any] = [:]
    @State private var showConfirmation = false
    @State private var showEndEarlyConfirmation = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "ant.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.red.opacity(0.8))

                    Text("Peggy")
                        .font(.custom("Georgia", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))

                    Text(reportType == .bugReport ? "Bug Report" : "Feature Suggestion")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.7))
                }
                .padding(.top, 60)

                // Audio level visualization
                if isSessionActive {
                    VStack(spacing: 8) {
                        // State indicator
                        Text(stateText)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.7))

                        // Audio waveform
                        HStack(spacing: 4) {
                            ForEach(0..<20, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor)
                                    .frame(width: 4, height: CGFloat.random(in: 10...50) * CGFloat(voiceSession.audioLevel + 0.1))
                                    .animation(.easeInOut(duration: 0.1), value: voiceSession.audioLevel)
                            }
                        }
                        .frame(height: 60)

                        // Conversation transcript
                        ScrollView {
                            Text(voiceSession.conversationText.isEmpty ? "Waiting for conversation..." : voiceSession.conversationText)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.8))
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // End and submit button (50% opacity with confirmation)
                if isSessionActive {
                    Button(action: { showEndEarlyConfirmation = true }) {
                        Text("End and Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(12)
                            .opacity(0.5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            // Close button (top-right) - Cancel and exit
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // End the voice session before dismissing (cleanup WebSocket, audio, etc.)
                        voiceSession.endSession()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.6))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel") {
                dismiss()
            }
        } message: {
            Text("Peggy needs microphone access to talk with you. Please enable it in Settings.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Are you sure you want to end the interview early?", isPresented: $showEndEarlyConfirmation) {
            Button("Keep Going", role: .cancel) {}
            Button("Submit Report", role: .destructive) {
                voiceSession.endSession()
            }
        } message: {
            Text("Your report may be incomplete. Ending now may make it harder for us to help you.")
        }
        .fullScreenCover(isPresented: $showConfirmation) {
            BugReportConfirmationView(
                reportType: reportType,
                conversationText: voiceSession.conversationText,
                signOffMessage: collectedData["sign_off_message"] as? String
            )
            .onDisappear {
                // When confirmation dismisses, dismiss the entire voice view
                dismiss()
            }
        }
        .task {
            await startVoiceSession()
        }
        .onChange(of: voiceSession.isConversationComplete) { _, complete in
            if complete {
                showConfirmation = true
            }
        }
    }

    private var stateText: String {
        switch voiceSession.state {
        case .idle:
            return "Ready"
        case .requestingPermission:
            return "Requesting Permission..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .listening:
            return "Listening..."
        case .processing:
            return "Peggy is thinking..."
        case .conversationComplete:
            return "Complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private func startVoiceSession() async {
        // Request microphone permission
        let hasPermission = await voiceSession.requestMicrophonePermission()

        guard hasPermission else {
            showingPermissionAlert = true
            return
        }

        // Set up interview type and context
        let userName = AuthManager.shared.user?.name
        let currentScreen = BugReportCaptureManager.currentScreen

        if reportType == .bugReport {
            voiceSession.interviewType = .bugReport(context: BugReportContext(
                userName: userName,
                currentScreen: currentScreen,
                metadata: capturedMetadata
            ))
        } else {
            voiceSession.interviewType = .suggestion(context: SuggestionContext(
                userName: userName,
                currentScreen: currentScreen
            ))
        }

        // Set up callback for when data is collected
        voiceSession.onPreferencesGathered = { data in
            NSLog("✅ Bug report data collected: \(data)")
            collectedData = data

            // Submit to backend
            Task {
                await submitReport(data: data)
            }
        }

        // Start session
        do {
            try await voiceSession.startSession()
            isSessionActive = true
        } catch {
            NSLog("❌ Failed to start voice session: \(error)")
            errorMessage = "Failed to start conversation: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    private func submitReport(data: [String: Any]) async {
        do {
            // Extract fields from function tool callback
            let summary = data["summary"] as? String ?? ""
            let category = data["category"] as? String ?? "other"
            let severityHint = data["severity_hint"] as? String
            let userDescription = data["user_description"] as? String
            let stepsToReproduce = data["steps_to_reproduce"] as? String
            let expectedBehavior = data["expected_behavior"] as? String

            // Build transcript from conversation history
            let transcript = voiceSession.conversationText

            // Determine report type
            let reportTypeString = reportType == .bugReport ? "bug" : "suggestion"

            _ = try await APIManager.shared.submitBugReport(
                reportType: reportTypeString,
                interviewMode: "voice",
                transcript: transcript,
                peggySummary: summary,
                category: category,
                severityHint: severityHint,
                userDescription: userDescription,
                stepsToReproduce: stepsToReproduce,
                expectedBehavior: expectedBehavior,
                screenshot: capturedScreenshot,
                metadata: capturedMetadata
            )
            NSLog("✅ \(reportTypeString) report submitted successfully")
        } catch {
            NSLog("❌ Failed to submit report: \(error)")
        }
    }
}

#Preview {
    BugReportVoiceView(
        reportType: .bugReport,
        capturedScreenshot: nil,
        capturedMetadata: [:]
    )
}
