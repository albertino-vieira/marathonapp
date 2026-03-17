//
//  marathonappApp.swift
//  marathonapp
//
//  Created by Albertino Vieira on 17/03/2026.
//

import SwiftUI

@main
struct marathonappApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            if appViewModel.showOnboarding {
                OnboardingView()
                    .environment(appViewModel)
            } else {
                MainTabView()
                    .environment(appViewModel)
            }
        }
    }
}
