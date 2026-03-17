//
//  ContentView.swift
//  marathonapp
//
//  Created by Albertino Vieira on 17/03/2026.
//

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            AnalysisView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.bar.xaxis")
                }

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "trophy.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppViewModel())
}
