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

    // API Keys

    // Supabase anon key - This is meant to be public (used in client apps)
    // Protected by Row Level Security policies in Supabase
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU"

    // NOTE: OpenAI API key is NOT stored client-side
    // Voice sessions get ephemeral tokens from backend via /onboarding/start

    // App Constants
    static let defaultFontSize: CGFloat = 18
    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 24
    static let defaultLineSpacing: CGFloat = 1.5
}
