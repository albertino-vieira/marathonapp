import SwiftUI
import Charts

// MARK: - AnalysisView

struct AnalysisView: View {
    @Environment(AppViewModel.self) var vm

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let readiness = vm.readiness {
                        readinessSection(readiness)
                        trainingLoadSection(readiness)
                        marathonPredictionSection(readiness)
                    } else {
                        emptyState
                    }
                    weeklyBreakdownSection
                    workoutDistributionSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private func readinessSection(_ readiness: MarathonReadiness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Readiness Overview")
            HStack(spacing: 16) {
                ReadinessRing(
                    score: readiness.score,
                    label: readiness.readinessLabel,
                    color: Color(readiness.readinessColor),
                    size: 110
                )
                VStack(spacing: 12) {
                    ReadinessRow(label: "Fitness (CTL)", value: readiness.fitness, color: .green)
                    ReadinessRow(label: "Fatigue (ATL)", value: readiness.fatigue, color: .orange)
                    ReadinessRow(label: "Form (TSB)", value: max(0, min(readiness.form + 50, 100)), color: readiness.form >= 0 ? .blue : .red)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Alerts
            if !readiness.alerts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(readiness.alerts) { alert in
                        AlertBanner(alert: alert)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func trainingLoadSection(_ readiness: MarathonReadiness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Training Load",
                subtitle: "Last 16 weeks"
            )
            VStack(spacing: 12) {
                HStack {
                    loadCard(title: "Fitness", value: readiness.fitness, color: .green, icon: "bolt.fill")
                    loadCard(title: "Fatigue", value: readiness.fatigue, color: .orange, icon: "battery.25")
                }
                HStack {
                    let formPct = max(0, min((readiness.form + 50) / 100 * 100, 100))
                    loadCard(title: "Form", value: formPct, color: readiness.form >= 0 ? .blue : .red, icon: "chart.line.uptrend.xyaxis")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(readiness.suggestedTodaySession.rawValue, systemImage: readiness.suggestedTodaySession.icon)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(readiness.suggestedTodaySession.color))
                        Text(readiness.recommendation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal)
        }
    }

    private func marathonPredictionSection(_ readiness: MarathonReadiness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Marathon Prediction")
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Predicted Finish Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let time = readiness.formattedPredictedTime {
                            Text(time)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                        } else {
                            Text("Not enough data")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Text("Based on Riegel formula from recent quality workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let target = vm.profile.targetMarathonTime {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Your Target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(target))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Distance predictions
                if let predicted = readiness.predictedMarathonTime {
                    Divider()
                    Text("Predicted Times by Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        predictionRow(label: "5km", distance: 5, from: 42.195, baseTime: predicted)
                        predictionRow(label: "10km", distance: 10, from: 42.195, baseTime: predicted)
                        predictionRow(label: "Half", distance: 21.0975, from: 42.195, baseTime: predicted)
                        predictionRow(label: "Marathon", distance: 42.195, from: 42.195, baseTime: predicted)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    private var weeklyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Weekly Breakdown", subtitle: "Last 12 weeks")
            let stats = Array(vm.weeklyStats.suffix(12))
            if stats.isEmpty {
                Text("No data available yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(stats) { week in
                            weekColumn(week)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func weekColumn(_ week: WeeklyStats) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%.0f", week.totalDistance))
                .font(.system(size: 11, weight: .semibold))

            RoundedRectangle(cornerRadius: 4)
                .fill(week.totalDistance > 0 ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: 28, height: max(CGFloat(week.totalDistance) * 2, 4))

            Text(week.shortLabel)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: 40)
    }

    private var workoutDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Workout Distribution", subtitle: "Last 30 days")
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let recent = vm.workouts.filter { $0.date >= thirtyDaysAgo }
            let typeCounts = Dictionary(grouping: recent, by: { $0.workoutType })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }

            if typeCounts.isEmpty {
                Text("No runs in the last 30 days.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(typeCounts, id: \.key) { type, count in
                        HStack {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.subheadline)
                                .foregroundColor(Color(type.color))
                                .frame(width: 130, alignment: .leading)
                            ProgressBar(
                                progress: Double(count) / Double(recent.count),
                                color: Color(type.color)
                            )
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Not Enough Data")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Sync at least 2 weeks of running data to see analysis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Helpers

    private func loadCard(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.0f", value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            ProgressBar(progress: value / 100, color: color, height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    private func predictionRow(label: String, distance: Double, from base: Double, baseTime: TimeInterval) -> some View {
        let predicted = baseTime * pow(distance / base, 1.06)
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formatTime(predicted))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - ReadinessRow

struct ReadinessRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            ProgressBar(progress: value / 100, color: color, height: 6)
        }
    }
}
