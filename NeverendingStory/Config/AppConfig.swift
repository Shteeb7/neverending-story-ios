//
//  AppConfig.swift
//  NeverendingStory
//
//  Configuration constants for the app
//

import Foundation

enum AppConfig {
    // Backend API
    static let apiBaseURL = "https://neverending-story-api-production.up.railway.app"

    // Supabase Configuration
    static let supabaseURL = "https://hszuuvkfgdfqgtaycojz.supabase.co"

    // Google OAuth Configuration
    static let googleClientID = "756674440214-q5afeoh7gk8h0tc72r7v687sdpp2o5ah.apps.googleusercontent.com"

    // API Keys - These are defined in AppConfig.local.swift (gitignored)
    // See API_KEYS_SETUP.md for instructions on creating AppConfig.local.swift

    // App Constants
    static let defaultFontSize: CGFloat = 18
    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 24
    static let defaultLineSpacing: CGFloat = 1.5
}
