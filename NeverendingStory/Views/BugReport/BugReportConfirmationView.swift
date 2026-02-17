//
//  BugReportConfirmationView.swift
//  NeverendingStory
//
//  Confirmation overlay after successful bug report submission
//  Shows "Thanks!" message and auto-dismisses after 2 seconds
//

import SwiftUI

struct BugReportConfirmationView: View {
    let reportType: BugReportView.ReportOption
    let conversationText: String

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Semi-transparent black background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 24) {
                // Checkmark icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(scale)

                // Thank you message
                VStack(spacing: 12) {
                    Text("Thanks!")
                        .font(.custom("Georgia", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(reportType == .bugReport ?
                         "Your bug report has been sent to the team." :
                         "Your suggestion has been recorded!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Close button
                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.top, 20)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}

#Preview {
    BugReportConfirmationView(
        reportType: .bugReport,
        conversationText: "Sample conversation text"
    )
}
