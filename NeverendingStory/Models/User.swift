//
//  User.swift
//  NeverendingStory
//
//  User data model
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let avatarURL: String?
    let createdAt: Date?
    let hasCompletedOnboarding: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case hasCompletedOnboarding = "has_completed_onboarding"
    }
}
