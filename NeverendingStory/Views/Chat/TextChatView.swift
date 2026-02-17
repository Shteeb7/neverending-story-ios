//
//  TextChatView.swift
//  NeverendingStory
//
//  Enchanted correspondence with Prospero - text-based interview alternative
//  DESIGN NOTE: This is NOT a chatbot. This is mystical written conversation with a wizard.
//

import SwiftUI

struct TextChatView: View {
    @StateObject private var chatSession = TextChatSessionManager()
    @State private var currentInput = ""
    @State private var typewriterText = ""
    @State private var currentTypewriterIndex = 0
    @State private var isTypewriterActive = false

    let interviewType: InterviewType
    let context: [String: Any]?
    let onComplete: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Mystical background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),   // Deep purple
                    Color(red: 0.05, green: 0.05, blue: 0.15), // Dark blue-purple
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle stars (simple particle effect)
            ForEach(0..<30, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.2...0.5)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }

            VStack(spacing: 0) {
                // Header with X button
                HStack {
                    Text("Correspondence with Prospero")
                        .font(.custom("Georgia", size: 18))
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))
                        .italic()
                    Spacer()

                    Button(action: {
                        // Cancel and exit (no submission)
                        onComplete()
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
                            ForEach(Array(chatSession.messages.enumerated()), id: \.element.id) { index, message in
                                if message.role == "assistant" && !message.content.contains("[Session started") {
                                    // Prospero's message - left side, serif, typewriter effect
                                    prosperoMessageView(message: message, isLatest: index == chatSession.messages.count - 1)
                                        .id(message.id)
                                } else if message.role == "user" {
                                    // User's message - right side, sans-serif
                                    userMessageView(message: message)
                                        .id(message.id)
                                }
                            }

                            // Loading indicator
                            if chatSession.isLoading {
                                prosperoThinkingView()
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
                        // End and Submit button (allows early completion)
                        Button(action: {
                            // Mark session as complete and trigger callback
                            chatSession.sessionComplete = true
                            if let callback = chatSession.onPreferencesGathered {
                                // Call with empty preferences dict (whatever was gathered so far)
                                callback([:])
                            }
                            onComplete()
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
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.6, green: 0.4, blue: 0.9),
                                        Color(red: 0.7, green: 0.3, blue: 0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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

                        Text("Connection failed")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(.white)

                        Text("Couldn't connect to your storyteller. Try again?")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            Task {
                                await chatSession.startSession(type: interviewType, context: context)
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
        .task {
            // Start session on appear
            await chatSession.startSession(type: interviewType, context: context)

            // Set up callback
            chatSession.onPreferencesGathered = { preferences in
                NSLog("✅ Text chat complete - preferences gathered")
                onComplete()
            }
        }
    }

    // MARK: - Prospero's Message View

    @ViewBuilder
    private func prosperoMessageView(message: ChatMessage, isLatest: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Small mystical icon
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5))
                .opacity(0.8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 0) {
                // Show typewriter effect only for the latest message
                if isLatest && !isTypewriterActive {
                    Text(typewriterText)
                        .font(.custom("Georgia", size: 17))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5))
                        .lineSpacing(4)
                        .onAppear {
                            startTypewriter(for: message.content)
                        }
                } else {
                    Text(message.content)
                        .font(.custom("Georgia", size: 17))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5))
                        .lineSpacing(4)
                }
            }
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

    // MARK: - Prospero Thinking Indicator

    @ViewBuilder
    private func prosperoThinkingView() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.6))

            Text("Prospero ponders...")
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.6))
                .italic()

            // Animated stars instead of dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.6))
                        .opacity(Double.random(in: 0.3...1.0))
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: UUID()
                        )
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Completion View

    @ViewBuilder
    private func completionView() -> some View {
        VStack(spacing: 20) {
            Button(action: {
                onComplete()
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))

                    Text(interviewType == .onboarding ? "Enter the Mythweaver" : "Complete Interview")
                        .font(.custom("Georgia", size: 18))
                        .fontWeight(.semibold)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16))
                }
                .foregroundColor(Color(red: 0.1, green: 0.05, blue: 0.2))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.85, blue: 0.5),
                            Color(red: 0.9, green: 0.75, blue: 0.4)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private func inputArea() -> some View {
        HStack(spacing: 12) {
            // Mystical text field
            HStack {
                TextField("", text: $currentInput, axis: .vertical)
                    .placeholder(when: currentInput.isEmpty) {
                        Text("Write to Prospero...")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.5))
                            .italic()
                    }
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.5))
                    .font(.system(size: 16))
                    .focused($isInputFocused)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                    .accessibilityIdentifier("textChatInput")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.6),
                                Color(red: 0.8, green: 0.6, blue: 0.3).opacity(0.4)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                    )
            )

            // Send button (glowing quill)
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(currentInput.isEmpty || chatSession.isLoading ? Color.gray : Color(red: 0.95, green: 0.85, blue: 0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .accessibilityIdentifier("sendMessageButton")
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

    // MARK: - Typewriter Effect

    private func startTypewriter(for text: String) {
        typewriterText = ""
        currentTypewriterIndex = 0
        isTypewriterActive = true

        let characters = Array(text)

        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if currentTypewriterIndex < characters.count {
                typewriterText.append(characters[currentTypewriterIndex])
                currentTypewriterIndex += 1
            } else {
                timer.invalidate()
                isTypewriterActive = false
            }
        }
    }
}

// MARK: - Custom TextField Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

struct TextChatView_Previews: PreviewProvider {
    static var previews: some View {
        TextChatView(
            interviewType: InterviewType.onboarding,
            context: [:],
            onComplete: {
                print("Chat complete!")
            }
        )
    }
}
