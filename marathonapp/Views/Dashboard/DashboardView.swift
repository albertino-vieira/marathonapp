import SwiftUI
import Charts

// MARK: - DashboardView

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showSyncConfirm = false
    @State private var selectedChartMode: ChartMode = .volume

    enum ChartMode: String, CaseIterable {
        case volume = "Volume"
        case pace = "Pace"
        case heartRate = "Heart Rate"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // MARK: Greeting + Sync
                    headerSection

                    // MARK: Alerts
                    if let alerts = vm.readiness?.alerts, !alerts.isEmpty {
                        alertsSection(alerts)
                    }

                    // MARK: Readiness
                    if let readiness = vm.readiness {
                        readinessSection(readiness)
                    }

                    // MARK: This Week Summary
                    thisWeekSection

                    // MARK: Charts
                    chartsSection

                    // MARK: Marathon Countdown
                    if let days = vm.profile.daysUntilMarathon, days > 0 {
                        marathonCountdownSection(days: days)
                    }

                    // MARK: Recent Workouts
                    recentWorkoutsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.syncWithHealthKit() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .alert("Sync Error", isPresented: .constant(vm.syncError != nil)) {
                Button("OK") { vm.syncError = nil }
            } message: {
                Text(vm.syncError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.bold)
                if let sync = vm.lastSyncDate {
                    Text("Last sync: \(sync.formatted(.relative(presentation: .numeric)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Sync to import your runs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue.gradient)
        }
        .padding(.horizontal)
    }

    private func alertsSection(_ alerts: [TrainingAlert]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Alerts", subtitle: "\(alerts.count) item\(alerts.count == 1 ? "" : "s")")
            VStack(spacing: 8) {
                ForEach(alerts.prefix(3)) { alert in
                    AlertBanner(alert: alert)
                }
            }
            .padding(.horizontal)
        }
    }

    private func readinessSection(_ readiness: MarathonReadiness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Readiness")
            HStack(spacing: 16) {
                ReadinessRing(
                    score: readiness.score,
                    label: readiness.readinessLabel,
                    color: Color(readiness.readinessColor),
                    size: 100
                )
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ReadinessRing(score: readiness.fitness, label: "Fitness", color: .green, size: 60)
                        ReadinessRing(score: readiness.fatigue, label: "Fatigue", color: .orange, size: 60)
                    }
                    Text(readiness.recommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Suggested session
            HStack {
                Image(systemName: readiness.suggestedTodaySession.icon)
                    .foregroundColor(Color(readiness.suggestedTodaySession.color))
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(readiness.suggestedTodaySession.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                if let predicted = readiness.formattedPredictedTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Predicted Marathon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(predicted)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "This Week",
                subtitle: "\(vm.thisWeekWorkouts.count) run\(vm.thisWeekWorkouts.count == 1 ? "" : "s")"
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(
                    title: "Distance",
                    value: String(format: "%.1f", vm.thisWeekKm),
                    unit: "km",
                    icon: "road.lanes",
                    color: .blue,
                    trend: vm.recentTrend.icon,
                    trendUp: vm.recentTrend == .improving
                )
                StatCard(
                    title: "Runs",
                    value: "\(vm.thisWeekWorkouts.count)",
                    unit: nil,
                    icon: "figure.run",
                    color: .green
                )
                if let pace = vm.weeklyStats.last?.averagePace, pace > 0 {
                    StatCard(
                        title: "Avg Pace",
                        value: formatPace(pace),
                        unit: "/km",
                        icon: "speedometer",
                        color: .orange
                    )
                }
                if let goal = vm.currentWeekGoal {
                    StatCard(
                        title: "Goal Progress",
                        value: String(format: "%.0f%%", goal.distanceProgress * 100),
                        unit: nil,
                        icon: "target",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)

            if let goal = vm.currentWeekGoal {
                weeklyGoalProgressBar(goal)
            }
        }
    }

    private func weeklyGoalProgressBar(_ goal: WeeklyGoal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weekly Goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f / %.0f km", goal.achievedDistance, goal.targetDistance))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            ProgressBar(progress: goal.distanceProgress, color: .blue)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Training Overview")
            Picker("Chart", selection: $selectedChartMode) {
                ForEach(ChartMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            let displayStats = Array(vm.weeklyStats.suffix(8))

            Group {
                switch selectedChartMode {
                case .volume:
                    WeeklyVolumeChart(stats: displayStats)
                case .pace:
                    PaceEvolutionChart(stats: displayStats)
                case .heartRate:
                    HeartRateChart(stats: displayStats)
                }
            }
            .frame(height: 180)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Week comparison
            if vm.weeklyStats.count >= 2 {
                let last2 = Array(vm.weeklyStats.suffix(2))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Week Comparison")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    WeekComparisonChart(thisWeek: last2[1], lastWeek: last2[0])
                        .frame(height: 120)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func marathonCountdownSection(days: Int) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Marathon Countdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("days")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                if let weeks = vm.profile.weeksUntilMarathon {
                    Text("\(weeks) weeks to go")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let date = vm.profile.marathonDate {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(date.formatted(.dateTime.day().month(.wide).year()))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let target = vm.profile.formattedTargetTime {
                        Label(target, systemImage: "flag.checkered")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent Runs", action: nil)
            if vm.workouts.isEmpty {
                emptyWorkoutsView
            } else {
                ForEach(vm.workouts.prefix(5)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        WorkoutRowView(workout: workout)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyWorkoutsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No runs yet")
                .font(.headline)
            Text("Sync with HealthKit to import your training data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.syncWithHealthKit() }
            } label: {
                Label("Sync HealthKit", systemImage: "heart.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = vm.profile.name.isEmpty ? "" : ", \(vm.profile.name)"
        switch hour {
        case 5..<12: return "Good morning\(name)"
        case 12..<17: return "Good afternoon\(name)"
        default: return "Good evening\(name)"
        }
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let mins = Int(secPerKm) / 60
        let secs = Int(secPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
