//
//  SeriesBadgeView.swift
//  NeverendingStory
//
//  Small badge showing "1 of 2", "2 of 3" etc. on book covers for series
//

import SwiftUI

struct SeriesBadgeView: View {
    let bookNumber: Int
    let totalBooks: Int

    var body: some View {
        Text("\(bookNumber) of \(totalBooks)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 0.3, green: 0.2, blue: 0.5).opacity(0.9))
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    SeriesBadgeView(bookNumber: 1, totalBooks: 3)
        .padding()
        .background(Color.gray.opacity(0.2))
}
