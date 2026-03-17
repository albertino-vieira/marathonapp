import SwiftUI

// MARK: - WorkoutsView

struct WorkoutsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var searchText = ""
    @State private var filterType: WorkoutType? = nil
    @State private var sortBy: SortOption = .date

    enum SortOption: String, CaseIterable {
        case date = "Date"
        case distance = "Distance"
        case pace = "Pace"
    }

    private var filtered: [RunWorkout] {
        var result = vm.workouts
        if let type = filterType {
            result = result.filter { $0.workoutType == type }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.formattedDistance.localizedCaseInsensitiveContains(searchText) ||
                $0.workoutType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortBy {
        case .date: result.sort { $0.date > $1.date }
        case .distance: result.sort { $0.distanceKm > $1.distanceKm }
        case .pace: result.sort { $0.averagePace < $1.averagePace }
        }
        return result
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                List {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search runs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil)
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    filterChip(label: type.rawValue, type: type)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func filterChip(label: String, type: WorkoutType?) -> some View {
        let isSelected = filterType == type
        return Button {
            filterType = type
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No runs found")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - WorkoutRowView

struct WorkoutRowView: View {
    let workout: RunWorkout

    var body: some View {
        HStack(spacing: 14) {
            // Date column
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(monthAbbr)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 36)

            // Type icon
            ZStack {
                Circle()
                    .fill(Color(workout.workoutType.color).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: workout.workoutType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(workout.workoutType.color))
            }

            // Main info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 10) {
                    Label(workout.formattedDistance, systemImage: "road.lanes")
                    Label(workout.formattedPace, systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Duration + HR
            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let hr = workout.averageHeartRate {
                    Label(String(format: "%.0f", hr), systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var dayNumber: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: workout.date)
    }

    private var monthAbbr: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: workout.date)
    }
}

// MARK: - WorkoutDetailView

struct WorkoutDetailView: View {
    let workout: RunWorkout

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                // Metrics grid
                metricsGrid
                // Splits chart
                if !workout.kmSplits.isEmpty {
                    splitsSection
                }
                // HR zones
                if let hr = workout.averageHeartRate {
                    hrSection(avgHR: hr)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(workout.workoutType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(workout.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.2f", workout.distanceKm))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("km")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            WorkoutTypeTag(type: workout.workoutType)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricBadge(label: "Time", value: workout.formattedDuration, color: .blue)
            MetricBadge(label: "Pace", value: workout.formattedPace, color: .orange)
            if let hr = workout.averageHeartRate {
                MetricBadge(label: "Avg HR", value: "\(Int(hr)) bpm", color: .red)
            }
            if let maxHR = workout.maxHeartRate {
                MetricBadge(label: "Max HR", value: "\(Int(maxHR)) bpm", color: .red)
            }
            if let cadence = workout.averageCadence {
                MetricBadge(label: "Cadence", value: "\(Int(cadence)) spm", color: .purple)
            }
            if let elev = workout.elevationGain {
                MetricBadge(label: "Elevation", value: "+\(Int(elev))m", color: .green)
            }
            if let cal = workout.calories {
                MetricBadge(label: "Calories", value: "\(Int(cal)) kcal", color: .yellow)
            }
        }
        .padding(.horizontal)
    }

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Km Splits")
            KmSplitsChart(splits: workout.kmSplits)
                .frame(height: 180)
                .padding(.horizontal)

            // Table view
            VStack(spacing: 0) {
                HStack {
                    Text("km").frame(width: 40, alignment: .leading)
                    Text("Pace").frame(maxWidth: .infinity, alignment: .leading)
                    Text("HR").frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()

                ForEach(workout.kmSplits) { split in
                    HStack {
                        Text("\(split.kilometer)")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text(split.formattedPace)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let hr = split.heartRate {
                            Text("\(Int(hr))")
                                .frame(width: 60, alignment: .trailing)
                                .foregroundColor(.red)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider().padding(.leading)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func hrSection(avgHR: Double) -> some View {
        let zone = HeartRateZone.zone(for: avgHR)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Heart Rate")
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .font(.headline)
                        .foregroundColor(Color(zone.color))
                    Text("Average: \(Int(avgHR)) bpm")
                        .font(.subheadline)
                    if let max = workout.maxHeartRate {
                        Text("Maximum: \(Int(max)) bpm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                ReadinessRing(
                    score: avgHR / (workout.maxHeartRate ?? 180) * 100,
                    label: "HR",
                    color: .red,
                    size: 70
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
}
