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

    // API Keys - Use local config if available, otherwise use placeholder
    #if DEBUG
    static var supabaseAnonKey: String {
        // Check if local config exists (via extension in AppConfig.local.swift)
        if let localKey = Self.supabaseAnonKeyLocal, localKey != "YOUR_SUPABASE_ANON_KEY" {
            return localKey
        }
        return "YOUR_SUPABASE_ANON_KEY" // Placeholder - add your key to AppConfig.local.swift
    }

    static var openAIAPIKey: String {
        // Check if local config exists (via extension in AppConfig.local.swift)
        if let localKey = Self.openAIAPIKeyLocal, localKey != "YOUR_OPENAI_API_KEY" {
            return localKey
        }
        return "YOUR_OPENAI_API_KEY" // Placeholder - add your key to AppConfig.local.swift
    }
    #else
    // Production builds should use environment variables or secure storage
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY"
    #endif

    // Optional local config (provided by AppConfig.local.swift if it exists)
    static var supabaseAnonKeyLocal: String? { nil }
    static var openAIAPIKeyLocal: String? { nil }

    // App Constants
    static let defaultFontSize: CGFloat = 18
    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 24
    static let defaultLineSpacing: CGFloat = 1.5
}
