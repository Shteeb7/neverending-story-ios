import SwiftUI

struct AgeGateView: View {
    @Environment(\.dismiss) var dismiss

    @State private var selectedMonth: Int? = nil
    @State private var selectedYear: Int? = nil
    @State private var showUnderageMessage = false

    var onAgeVerified: (Int, Int, Bool) -> Void // (month, year, isMinor)

    private let months = [
        (1, "January"), (2, "February"), (3, "March"), (4, "April"),
        (5, "May"), (6, "June"), (7, "July"), (8, "August"),
        (9, "September"), (10, "October"), (11, "November"), (12, "December")
    ]

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1920...currentYear).reversed())
    }

    private var canContinue: Bool {
        selectedMonth != nil && selectedYear != nil
    }

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

            if showUnderageMessage {
                underageMessageView
            } else {
                mainContentView
            }
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: 60)

            // Crystal ball icon
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                .padding(.bottom, 8)

            // Heading
            Text("When Did Your Story Begin?")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Atmospheric subtext
            Text("Every great tale has a beginning...")
                .font(.system(size: 17, design: .serif))
                .italic()
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 20)

            // Date pickers (month and year side by side)
            HStack(spacing: 16) {
                // Month picker
                VStack(spacing: 8) {
                    Text("Month")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.7))

                    Picker("Month", selection: Binding(
                        get: { selectedMonth ?? 0 },
                        set: { selectedMonth = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Select").tag(0)
                            .foregroundColor(Color.white.opacity(0.4))
                        ForEach(months, id: \.0) { month in
                            Text(month.1).tag(month.0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .colorScheme(.dark)
                }

                // Year picker
                VStack(spacing: 8) {
                    Text("Year")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.7))

                    Picker("Year", selection: Binding(
                        get: { selectedYear ?? 0 },
                        set: { selectedYear = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Select").tag(0)
                            .foregroundColor(Color.white.opacity(0.4))
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .colorScheme(.dark)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button(action: handleContinue) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: canContinue ? [
                                Color(red: 0.6, green: 0.4, blue: 0.9),
                                Color(red: 0.7, green: 0.3, blue: 0.8)
                            ] : [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(canContinue ? .white : Color.white.opacity(0.4))
                    .cornerRadius(16)
            }
            .disabled(!canContinue)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var underageMessageView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Gentle icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                .padding(.bottom, 16)

            // Warm, friendly message
            VStack(spacing: 16) {
                Text("Mythweaver is crafted for readers 13 and older.")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("We hope to see you when you're ready!")
                    .font(.system(size: 18, design: .serif))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Got It button
            Button(action: {
                dismiss()
            }) {
                Text("Got It")
                    .font(.system(size: 18, weight: .semibold))
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
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func handleContinue() {
        guard let month = selectedMonth, let year = selectedYear else { return }

        // Calculate age using conservative month/year approach
        let age = calculateAge(birthMonth: month, birthYear: year)

        if age < 13 {
            // Under 13: show friendly block message
            showUnderageMessage = true
        } else {
            // 13+: proceed with account creation
            let isMinor = age < 18
            onAgeVerified(month, year, isMinor)
        }
    }

    /// Conservative age calculation: if birth month hasn't fully passed in current year, assume birthday hasn't occurred yet
    private func calculateAge(birthMonth: Int, birthYear: Int) -> Int {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        var age = currentYear - birthYear

        // If birth month hasn't fully passed yet, subtract 1 (conservative approach)
        if currentMonth < birthMonth {
            age -= 1
        }

        return age
    }
}

#Preview {
    AgeGateView(onAgeVerified: { month, year, isMinor in
        print("Age verified: \(month)/\(year), isMinor: \(isMinor)")
    })
}
