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
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY" // Add your Supabase anon key here

    // OpenAI Configuration
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY" // Add your OpenAI API key here

    // App Constants
    static let defaultFontSize: CGFloat = 18
    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 24
    static let defaultLineSpacing: CGFloat = 1.5
}
