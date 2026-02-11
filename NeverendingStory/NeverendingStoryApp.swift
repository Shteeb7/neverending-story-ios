//
//  NeverendingStoryApp.swift
//  NeverendingStory
//
//  Main app entry point
//

import SwiftUI
import GoogleSignIn

@main
struct NeverendingStoryApp: App {
    init() {
        // TEST: Verify logging works
        NSLog("🚀🚀🚀 APP STARTED - NeverendingStory launching! 🚀🚀🚀")
        print("🚀🚀🚀 APP STARTED (print) - NeverendingStory launching! 🚀🚀🚀")

        configureAppearance()
        configureGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func configureAppearance() {
        // Set accent color
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .systemIndigo

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private func configureGoogleSignIn() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AppConfig.googleClientID
        )
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        // Add custom URL handling here if needed in the future
    }
}
