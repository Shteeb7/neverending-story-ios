//
//  StoryFeedbackDialog.swift
//  NeverendingStory
//
//  Cassandra's check-in dialog at chapter checkpoints
//

import SwiftUI

struct StoryFeedbackDialog: View {
    let checkpoint: String // "chapter_3", "chapter_6", or "chapter_9"
    let onResponse: (String) -> Void

    @State private var isAnimating = false
    
    private var checkpointNumber: Int {
        if checkpoint == "chapter_3" { return 3 }
        if checkpoint == "chapter_6" { return 6 }
        return 9
    }
    
    private var message: String {
        switch checkpoint {
        case "chapter_3":
            return "You're halfway through! How are you feeling about this story?"
        case "chapter_6":
            return "We're getting close to the end! How's the adventure going?"
        case "chapter_9":
            return "Almost done! I'd love to hear how you're enjoying it."
        default:
            return "Quick check-in! How are you feeling about this story?"
        }
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            VStack(spacing: 32) {
                // Cassandra avatar with animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.blue.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .purple.opacity(0.3), radius: 20)
                
                // Message
                VStack(spacing: 12) {
                    Text("Cassandra here!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                
                // Response buttons
                VStack(spacing: 16) {
                    ForEach(["Fantastic", "Great", "Meh"], id: \.self) { response in
                        Button(action: {
                            onResponse(response)
                        }) {
                            HStack {
                                // Emoji
                                Text(emojiFor(response: response))
                                    .font(.title2)
                                
                                Text(response)
                                    .font(.headline)
                                    .foregroundColor(colorFor(response: response))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(backgroundFor(response: response))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(colorFor(response: response), lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private func emojiFor(response: String) -> String {
        switch response {
        case "Fantastic": return "🤩"
        case "Great": return "😊"
        case "Meh": return "😐"
        default: return ""
        }
    }
    
    private func colorFor(response: String) -> Color {
        switch response {
        case "Fantastic": return .purple
        case "Great": return .blue
        case "Meh": return .orange
        default: return .gray
        }
    }
    
    private func backgroundFor(response: String) -> Color {
        colorFor(response: response).opacity(0.1)
    }
}

#Preview {
    StoryFeedbackDialog(checkpoint: "chapter_3") { response in
        print("Selected: \(response)")
    }
}
