//
//  BugReportView.swift
//  NeverendingStory
//
//  Modal selection UI for bug reporting
//  User chooses: Report a Bug (voice/text) or Suggest a Feature (voice/text)
//

import SwiftUI
import UIKit

struct BugReportView: View {
    let capturedScreenshot: UIImage?
    let capturedMetadata: [String: Any]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: ReportOption?
    @State private var showVoiceInterview = false
    @State private var showTextChat = false

    enum ReportOption {
        case bugReport
        case suggestion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "ant.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.red.opacity(0.8))

                        Text("Talk to Peggy")
                            .font(.custom("Georgia", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6))

                        Text("Your friendly bug catcher")
                            .font(.custom("Georgia", size: 16))
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.7))
                            .italic()
                    }
                    .padding(.top, 40)

                    // Options
                    VStack(spacing: 20) {
                        // Report a Bug
                        OptionButton(
                            title: "Report a Bug",
                            subtitle: "Something's not working right",
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .red,
                            isSelected: selectedOption == .bugReport
                        ) {
                            selectedOption = .bugReport
                        }
                        .accessibilityIdentifier("reportBugButton")

                        // Suggest a Feature
                        OptionButton(
                            title: "Suggest a Feature",
                            subtitle: "I have an idea!",
                            icon: "lightbulb.fill",
                            iconColor: .yellow,
                            isSelected: selectedOption == .suggestion
                        ) {
                            selectedOption = .suggestion
                        }
                        .accessibilityIdentifier("suggestFeatureButton")
                    }
                    .padding(.horizontal, 24)

                    // Voice/Text Choice (only if option selected)
                    if selectedOption != nil {
                        VStack(spacing: 16) {
                            Text("How would you like to chat?")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.8))

                            HStack(spacing: 16) {
                                // Voice button
                                Button(action: {
                                    showVoiceInterview = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 18))
                                        Text("Voice")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                                }
                                .accessibilityIdentifier("voiceChatButton")

                                // Text button
                                Button(action: {
                                    showTextChat = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "text.bubble.fill")
                                            .font(.system(size: 18))
                                        Text("Text")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accentColor.opacity(0.8))
                                    .cornerRadius(12)
                                }
                                .accessibilityIdentifier("textChatButton")
                            }
                            .padding(.horizontal, 24)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: selectedOption)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.6))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showVoiceInterview) {
            if let option = selectedOption {
                BugReportVoiceView(
                    reportType: option,
                    capturedScreenshot: capturedScreenshot,
                    capturedMetadata: capturedMetadata
                )
            }
        }
        .fullScreenCover(isPresented: $showTextChat) {
            if let option = selectedOption {
                BugReportTextChatView(
                    reportType: option,
                    capturedScreenshot: capturedScreenshot,
                    capturedMetadata: capturedMetadata
                )
            }
        }
    }
}

// MARK: - Option Button Component

struct OptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                    .frame(width: 50)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.green.opacity(0.6) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
    }
}

#Preview {
    BugReportView(
        capturedScreenshot: nil,
        capturedMetadata: [:]
    )
}
