import SwiftUI
import Charts

// MARK: - WeeklyVolumeChart

struct WeeklyVolumeChart: View {
    let stats: [WeeklyStats]
    var selectedWeek: WeeklyStats? = nil

    var body: some View {
        Chart(stats) { week in
            BarMark(
                x: .value("Week", week.shortLabel),
                y: .value("km", week.totalDistance)
            )
            .foregroundStyle(
                selectedWeek?.id == week.id ? Color.accentColor : Color.accentColor.opacity(0.7)
            )
            .cornerRadius(4)
            .annotation(position: .top) {
                if week.totalDistance > 0 {
                    Text(String(format: "%.0f", week.totalDistance))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(size: 10))
                AxisGridLine()
            }
        }
    }
}

// MARK: - PaceEvolutionChart

struct PaceEvolutionChart: View {
    let stats: [WeeklyStats]

    private var validStats: [WeeklyStats] {
        stats.filter { $0.averagePace > 0 }
    }

    var body: some View {
        Chart(validStats) { week in
            LineMark(
                x: .value("Week", week.shortLabel),
                y: .value("Pace", week.averagePace / 60)   // display as minutes
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.orange)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("Week", week.shortLabel),
                y: .value("Pace", week.averagePace / 60)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.orange.opacity(0.1))

            PointMark(
                x: .value("Week", week.shortLabel),
                y: .value("Pace", week.averagePace / 60)
            )
            .foregroundStyle(Color.orange)
            .symbolSize(30)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let v = value.as(Double.self) {
                    let mins = Int(v)
                    let secs = Int((v - Double(mins)) * 60)
                    AxisValueLabel {
                        Text(String(format: "%d:%02d", mins, secs))
                            .font(.system(size: 10))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
    }
}

// MARK: - HeartRateChart

struct HeartRateChart: View {
    let stats: [WeeklyStats]

    private var validStats: [WeeklyStats] {
        stats.filter { ($0.averageHeartRate ?? 0) > 0 }
    }

    var body: some View {
        Chart(validStats) { week in
            LineMark(
                x: .value("Week", week.shortLabel),
                y: .value("HR", week.averageHeartRate ?? 0)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.red)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("Week", week.shortLabel),
                y: .value("HR", week.averageHeartRate ?? 0)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.red.opacity(0.1))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(size: 10))
                AxisGridLine()
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
    }
}

// MARK: - KmSplitsChart

struct KmSplitsChart: View {
    let splits: [KmSplit]

    private var avgPace: Double {
        guard !splits.isEmpty else { return 0 }
        return splits.map { $0.pace }.reduce(0, +) / Double(splits.count)
    }

    var body: some View {
        Chart(splits) { split in
            BarMark(
                x: .value("km", split.kilometer),
                y: .value("Pace", split.pace / 60)
            )
            .foregroundStyle(paceColor(split.pace))
            .cornerRadius(3)
            RuleMark(y: .value("Average", avgPace / 60))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(Color.secondary)
                .annotation(position: .trailing) {
                    Text("Avg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { v in
                if let val = v.as(Int.self) {
                    AxisValueLabel { Text("\(val)km").font(.system(size: 9)) }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let v = value.as(Double.self) {
                    let mins = Int(v)
                    let secs = Int((v - Double(mins)) * 60)
                    AxisValueLabel {
                        Text(String(format: "%d:%02d", mins, secs))
                            .font(.system(size: 10))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    private func paceColor(_ pace: Double) -> Color {
        guard avgPace > 0 else { return .blue }
        let ratio = pace / avgPace
        if ratio < 0.95 { return .green }
        if ratio > 1.05 { return .red }
        return .blue
    }
}

// MARK: - WeekComparisonChart

struct WeekComparisonChart: View {
    let thisWeek: WeeklyStats
    let lastWeek: WeeklyStats

    var body: some View {
        Chart {
            BarMark(
                x: .value("Period", "Last Week"),
                y: .value("km", lastWeek.totalDistance)
            )
            .foregroundStyle(Color.secondary.opacity(0.6))
            .cornerRadius(6)
            .annotation(position: .top) {
                Text(String(format: "%.1f km", lastWeek.totalDistance))
                    .font(.caption2).foregroundColor(.secondary)
            }

            BarMark(
                x: .value("Period", "This Week"),
                y: .value("km", thisWeek.totalDistance)
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(6)
            .annotation(position: .top) {
                Text(String(format: "%.1f km", thisWeek.totalDistance))
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.subheadline) }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.caption)
                AxisGridLine()
            }
        }
    }
}
