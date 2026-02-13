//
//  MehFollowUpDialog.swift
//  NeverendingStory
//
//  Follow-up dialog when user responds "Meh" to feedback
//

import SwiftUI

struct MehFollowUpDialog: View {
    let onAction: (String) -> Void // "different_story", "keep_reading", or "voice_tips"

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("No worries!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("What would you like to do?")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    // Start different story
                    Button(action: {
                        onAction("different_story")
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "books.vertical")
                                    .font(.title2)
                                Text("Start a Different Story")
                                    .font(.headline)
                            }
                            Text("Choose from other available stories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    
                    // Keep reading
                    Button(action: {
                        onAction("keep_reading")
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "book.pages")
                                    .font(.title2)
                                Text("Keep Reading")
                                    .font(.headline)
                            }
                            Text("Maybe it gets better! Let's continue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    }
                    
                    // Give story tips
                    Button(action: {
                        onAction("voice_tips")
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .font(.title2)
                                Text("Give Story Tips")
                                    .font(.headline)
                            }
                            Text("Talk to Prospero about what could be better")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple, lineWidth: 2)
                        )
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
    }
}

#Preview {
    MehFollowUpDialog { action in
        print("Selected: \(action)")
    }
}
