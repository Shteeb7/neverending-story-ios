//
//  BugReportTextChatView.swift
//  NeverendingStory
//
//  Text chat adaptation for Peggy bug reporting
//  Based on TextChatView but customized for bug reports/suggestions
//

import SwiftUI

struct BugReportTextChatView: View {
    let reportType: BugReportView.ReportOption
    let capturedScreenshot: UIImage?
    let capturedMetadata: [String: Any]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatSession = TextChatSessionManager()
    @State private var currentInput = ""
    @State private var collectedData: [String: Any] = [:]
    @State private var showConfirmation = false

    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient (slightly different from Prospero - more red tint)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.15, green: 0.05, blue: 0.1),   // Slight red tint
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (customized for Peggy)
                HStack {
                    Image(systemName: "ant.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.red.opacity(0.8))

                    Text("Line Open — Peggy, QA Division")
                        .font(.custom("Georgia", size: 18))
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                        .italic()

                    Spacer()

                    Button(action: {
                        // Cancel and exit (no submission)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 10)

                // Message scroll view
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            ForEach(chatSession.messages) { message in
                                if message.role == "assistant" {
                                    // Peggy's message - left side, friendly
                                    peggyMessageView(message: message)
                                        .id(message.id)
                                } else if message.role == "user" {
                                    // User's message - right side
                                    userMessageView(message: message)
                                        .id(message.id)
                                }
                            }

                            // Loading indicator
                            if chatSession.isLoading {
                                peggyThinkingView()
                            }

                            // Completion state
                            if chatSession.sessionComplete {
                                completionView()
                            }

                            // Scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .onChange(of: chatSession.messages.count) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: chatSession.isLoading) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                // Input area with End and Submit button
                if chatSession.isSessionActive && !chatSession.sessionComplete {
                    VStack(spacing: 12) {
                        // End and Submit button (allows early submission)
                        Button(action: {
                            // Mark session as complete
                            chatSession.sessionComplete = true
                            // Trigger completion callback with whatever data was collected
                            if let callback = chatSession.onPreferencesGathered {
                                callback(collectedData)
                            }
                            showConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("End and Submit")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        inputArea()
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 15)
                    .background(
                        Color.black.opacity(0.5)
                            .blur(radius: 10)
                    )
                } else if chatSession.error != nil {
                    // Show error state with retry
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))

                        Text("Peggy's line is down")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(.white)

                        Text("Couldn't connect to the switchboard. Give it another ring?")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            Task {
                                let interviewType: InterviewType
                                if reportType == .bugReport {
                                    interviewType = .bugReport(context: BugReportContext(
                                        userName: AuthManager.shared.user?.name,
                                        currentScreen: BugReportCaptureManager.currentScreen,
                                        metadata: capturedMetadata
                                    ))
                                } else {
                                    interviewType = .suggestion(context: SuggestionContext(
                                        userName: AuthManager.shared.user?.name,
                                        currentScreen: BugReportCaptureManager.currentScreen
                                    ))
                                }
                                await chatSession.startSession(type: interviewType)
                            }
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.9))
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }
            }
        }
        .fullScreenCover(isPresented: $showConfirmation) {
            BugReportConfirmationView(
                reportType: reportType,
                conversationText: chatSession.messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n"),
                signOffMessage: collectedData["sign_off_message"] as? String
            )
            .onDisappear {
                // When confirmation dismisses, dismiss the entire chat view
                dismiss()
            }
        }
        .task {
            // Determine interview type
            let userName = AuthManager.shared.user?.name
            let currentScreen = BugReportCaptureManager.currentScreen

            let interviewType: InterviewType
            if reportType == .bugReport {
                interviewType = .bugReport(context: BugReportContext(
                    userName: userName,
                    currentScreen: currentScreen,
                    metadata: capturedMetadata
                ))
            } else {
                interviewType = .suggestion(context: SuggestionContext(
                    userName: userName,
                    currentScreen: currentScreen
                ))
            }

            // Start session
            await chatSession.startSession(type: interviewType)

            // Set up callback
            chatSession.onPreferencesGathered = { data in
                NSLog("✅ Bug report data collected: \(data)")
                collectedData = data

                // Submit to backend
                Task {
                    await submitReport(data: data)
                }

                // Show confirmation
                showConfirmation = true
            }
        }
    }

    // MARK: - Peggy's Message View

    @ViewBuilder
    private func peggyMessageView(message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Bug icon
            Image(systemName: "ant.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.red.opacity(0.8))
                .padding(.top, 4)

            Text(message.content)
                .font(.system(size: 17))
                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                .lineSpacing(4)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)

            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    // MARK: - User's Message View

    @ViewBuilder
    private func userMessageView(message: ChatMessage) -> some View {
        HStack {
            Spacer()

            Text(message.content)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.95))
                .lineSpacing(3)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                .padding(12)
                .background(
                    Color.white.opacity(0.08)
                        .cornerRadius(12)
                )
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Peggy Thinking Indicator

    @ViewBuilder
    private func peggyThinkingView() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "ant.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.red.opacity(0.6))

            Text("Peggy is thinking...")
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.6))
                .italic()

            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Completion View

    @ViewBuilder
    private func completionView() -> some View {
        VStack(spacing: 20) {
            Button(action: {
                showConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))

                    Text("Submit Report")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private func inputArea() -> some View {
        HStack(spacing: 12) {
            // Text field
            HStack {
                TextField("", text: $currentInput, axis: .vertical)
                    .placeholder(when: currentInput.isEmpty) {
                        Text("Type your message...")
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.5))
                            .italic()
                    }
                    .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                    .font(.system(size: 16))
                    .focused($isInputFocused)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                    .accessibilityIdentifier("peggyTextChatInput")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.red.opacity(0.6),
                        lineWidth: 1.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                    )
            )

            // Send button
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(currentInput.isEmpty || chatSession.isLoading ? Color.gray : Color.red.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .accessibilityIdentifier("sendPeggyMessageButton")
            .disabled(currentInput.isEmpty || chatSession.isLoading)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !currentInput.isEmpty, !chatSession.isLoading else { return }

        let message = currentInput
        currentInput = ""
        isInputFocused = false

        Task {
            await chatSession.sendMessage(message)
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

            // Build transcript from chat session messages
            let transcript = chatSession.messages.map { "\($0.role == "user" ? "You" : "Peggy"): \($0.content)" }.joined(separator: "\n\n")

            // Determine report type
            let reportTypeString = reportType == .bugReport ? "bug" : "suggestion"

            _ = try await APIManager.shared.submitBugReport(
                reportType: reportTypeString,
                interviewMode: "text",
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
    BugReportTextChatView(
        reportType: .bugReport,
        capturedScreenshot: nil,
        capturedMetadata: [:]
    )
}
