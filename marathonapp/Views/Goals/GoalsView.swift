import SwiftUI

// MARK: - GoalsView

struct GoalsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showEditGoal = false
    @State private var goalKm: Double = 40
    @State private var goalSessions: Int = 4

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    weeklyGoalSection
                    personalRecordsSection
                    achievementsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goals & PRs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        goalKm = vm.profile.weeklyGoalKm
                        goalSessions = vm.profile.weeklyGoalSessions
                        showEditGoal = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditGoal) {
                EditGoalSheet(km: $goalKm, sessions: $goalSessions) {
                    vm.setWeeklyGoal(km: goalKm, sessions: goalSessions)
                    showEditGoal = false
                }
            }
        }
    }

    // MARK: - Weekly Goal

    private var weeklyGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This Week's Goal")
            if let goal = vm.currentWeekGoal {
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        goalRing(
                            progress: goal.distanceProgress,
                            achieved: String(format: "%.1f", goal.achievedDistance),
                            target: String(format: "%.0f", goal.targetDistance),
                            unit: "km",
                            color: .blue
                        )
                        goalRing(
                            progress: goal.sessionsProgress,
                            achieved: "\(goal.achievedSessions)",
                            target: "\(goal.targetSessions)",
                            unit: "runs",
                            color: .green
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.isAchieved ? "Goal Achieved!" : "Keep going!")
                                .font(.headline)
                                .foregroundColor(goal.isAchieved ? .green : .primary)
                            if !goal.isAchieved {
                                let remaining = goal.targetDistance - goal.achievedDistance
                                Text(String(format: "%.1f km to goal", remaining))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let remainingSessions = goal.targetSessions - goal.achievedSessions
                                if remainingSessions > 0 {
                                    Text("\(remainingSessions) more run\(remainingSessions == 1 ? "" : "s") this week")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                Button {
                    showEditGoal = true
                } label: {
                    Label("Set Weekly Goal", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
    }

    private func goalRing(progress: Double, achieved: String, target: String, unit: String, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
            VStack(spacing: 0) {
                Text(achieved)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Records")
            if vm.personalRecords.isEmpty {
                Text("Sync your runs to see personal records.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(vm.personalRecords) { pr in
                        PRCard(record: pr)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(computeAchievements(), id: \.title) { ach in
                    AchievementBadge(achievement: ach)
                }
            }
            .padding(.horizontal)
        }
    }

    private func computeAchievements() -> [Achievement] {
        var list: [Achievement] = []
        let count = vm.workouts.count
        if count >= 1  { list.append(Achievement(title: "First Run", icon: "figure.run", unlocked: true)) }
        if count >= 10 { list.append(Achievement(title: "10 Runs", icon: "10.circle.fill", unlocked: true)) }
        if count >= 50 { list.append(Achievement(title: "50 Runs", icon: "50.circle.fill", unlocked: true)) }
        let totalKm = vm.workouts.reduce(0.0) { $0 + $1.distanceKm }
        if totalKm >= 100 { list.append(Achievement(title: "100 km", icon: "road.lanes.curved.right", unlocked: true)) }
        if totalKm >= 500 { list.append(Achievement(title: "500 km", icon: "globe.europe.africa", unlocked: true)) }
        let hasLong = vm.workouts.contains { $0.distanceKm >= 21 }
        list.append(Achievement(title: "Half Marathon", icon: "h.circle.fill", unlocked: hasLong))
        let hasFull = vm.workouts.contains { $0.distanceKm >= 42 }
        list.append(Achievement(title: "Marathon", icon: "m.circle.fill", unlocked: hasFull))
        // Consistency
        let consecutiveWeeks = consecutiveActiveWeeks()
        if consecutiveWeeks >= 4 {
            list.append(Achievement(title: "4-Week Streak", icon: "flame.fill", unlocked: true))
        }
        return list
    }

    private func consecutiveActiveWeeks() -> Int {
        let stats = AnalyticsService.shared.buildWeeklyStats(from: vm.workouts, numberOfWeeks: 12)
        var streak = 0
        for week in stats.reversed() {
            if week.workoutCount > 0 { streak += 1 } else { break }
        }
        return streak
    }
}

// MARK: - PRCard

struct PRCard: View {
    let record: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: record.type.icon)
                    .foregroundColor(.yellow)
                    .font(.title3)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
            Text(record.formattedValue)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(record.type.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(record.date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - AchievementBadge

struct Achievement {
    let title: String
    let icon: String
    let unlocked: Bool
}

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.unlocked ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.unlocked ? .yellow : .secondary)
                if !achievement.unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .offset(x: 16, y: 16)
                }
            }
            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.unlocked ? .primary : .secondary)
        }
        .opacity(achievement.unlocked ? 1.0 : 0.5)
    }
}

// MARK: - EditGoalSheet

struct EditGoalSheet: View {
    @Binding var km: Double
    @Binding var sessions: Int
    var onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Distance Goal") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%.0f km per week", km))
                            .font(.headline)
                        Slider(value: $km, in: 10...120, step: 5)
                            .accentColor(.blue)
                    }
                }
                Section("Sessions Goal") {
                    Stepper("\(sessions) runs per week", value: $sessions, in: 1...7)
                }
            }
            .navigationTitle("Edit Weekly Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
