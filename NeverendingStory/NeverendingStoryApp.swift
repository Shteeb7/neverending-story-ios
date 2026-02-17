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

        // Detect UI testing mode and reset app state
        if CommandLine.arguments.contains("--uitesting") {
            NSLog("🧪 UI Testing mode detected - clearing app state")
            resetAppStateForTesting()
        }

        configureAppearance()
        configureGoogleSignIn()
    }

    private func resetAppStateForTesting() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            NSLog("🧪 Cleared UserDefaults for bundle: \(bundleID)")
        }

        // Clear all cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
            NSLog("🧪 Cleared \(cookies.count) cookies")
        }

        // Clear Keychain (Supabase stores sessions here)
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]

        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }
        NSLog("🧪 Cleared Keychain items")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LaunchView()
                    .overlay(alignment: .bottom) {
                        GlobalVersionOverlay()
                    }
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }

                // Bug reporter icon always on top
                BugReportOverlay()
                    .zIndex(.infinity)
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
