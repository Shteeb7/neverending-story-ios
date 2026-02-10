//
//  NeverendingStoryApp.swift
//  NeverendingStory
//
//  Main app entry point
//

import SwiftUI

@main
struct NeverendingStoryApp: App {
    init() {
        // Configure app appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
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
}
