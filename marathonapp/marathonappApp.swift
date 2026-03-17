//
//  marathonappApp.swift
//  marathonapp
//
//  Created by Albertino Vieira on 17/03/2026.
//

import SwiftUI

@main
struct marathonappApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            if appViewModel.showOnboarding {
                OnboardingView()
                    .environmentObject(appViewModel)
            } else {
                MainTabView()
                    .environmentObject(appViewModel)
            }
        }
    }
}
