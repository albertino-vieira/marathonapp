import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var editedProfile: RunnerProfile = RunnerProfile()
    @State private var showingDatePicker = false

    var body: some View {
        NavigationView {
            Form {
                profileSection
                marathonSection
                healthKitSection
                goalsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { editedProfile = vm.profile }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        vm.saveProfile(editedProfile)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                Label("Name", systemImage: "person")
                Spacer()
                TextField("Your name", text: $editedProfile.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("Age", systemImage: "calendar.badge.clock")
                Spacer()
                TextField("Age", value: $editedProfile.age, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            HStack {
                Label("Resting HR", systemImage: "heart")
                Spacer()
                TextField("bpm", value: $editedProfile.restingHeartRate, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                Text("bpm").foregroundColor(.secondary).font(.subheadline)
            }
            HStack {
                Label("Max HR", systemImage: "heart.fill")
                Spacer()
                TextField("Auto", value: $editedProfile.maxHeartRate, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                Text("bpm").foregroundColor(.secondary).font(.subheadline)
            }
            Picker("Fitness Level", selection: $editedProfile.fitnessLevel) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
        }
    }

    private var marathonSection: some View {
        Section("Marathon") {
            DatePicker(
                "Marathon Date",
                selection: Binding(
                    get: { editedProfile.marathonDate ?? Date() },
                    set: { editedProfile.marathonDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            HStack {
                Label("Target Time", systemImage: "flag.checkered")
                Spacer()
                if let target = editedProfile.formattedTargetTime {
                    Text(target)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not set")
                        .foregroundColor(.secondary)
                }
            }

            NavigationLink(destination: TargetTimePickerView(
                targetTime: Binding(
                    get: { editedProfile.targetMarathonTime ?? 14400 },
                    set: { editedProfile.targetMarathonTime = $0 }
                )
            )) {
                Label("Set Target Time", systemImage: "timer")
            }

            if let days = editedProfile.daysUntilMarathon, days > 0 {
                HStack {
                    Label("Days Until Race", systemImage: "calendar")
                    Spacer()
                    Text("\(days) days")
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
            }

            Button {
                vm.regeneratePlan()
            } label: {
                Label("Regenerate Training Plan", systemImage: "arrow.clockwise")
            }
            .disabled(editedProfile.marathonDate == nil)
        }
    }

    private var healthKitSection: some View {
        Section("HealthKit") {
            HStack {
                Label("Status", systemImage: "heart.text.square")
                Spacer()
                switch HealthKitService.shared.authorizationStatus {
                case .authorized:
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                case .denied:
                    Label("Denied", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                case .notDetermined:
                    Label("Not set", systemImage: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }

            Button {
                Task { await vm.requestHealthKitPermission() }
            } label: {
                Label("Request Permission", systemImage: "heart.fill")
            }

            Button {
                Task { await vm.syncWithHealthKit() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(vm.isLoading)

            if let last = vm.lastSyncDate {
                HStack {
                    Label("Last Sync", systemImage: "clock")
                    Spacer()
                    Text(last.formatted(.relative(presentation: .named)))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }

    private var goalsSection: some View {
        Section("Weekly Goals") {
            HStack {
                Label("Distance Goal", systemImage: "road.lanes")
                Spacer()
                TextField("km", value: $editedProfile.weeklyGoalKm, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                Text("km").foregroundColor(.secondary).font(.subheadline)
            }
            Stepper(
                "Sessions: \(editedProfile.weeklyGoalSessions) per week",
                value: $editedProfile.weeklyGoalSessions,
                in: 1...7
            )
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("App", systemImage: "figure.run")
                Spacer()
                Text("MarathonApp")
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0 MVP")
                    .foregroundColor(.secondary)
            }
            Link(destination: URL(string: "https://www.apple.com/health/")!) {
                Label("Apple Health", systemImage: "heart.fill")
            }
        }
    }
}

// MARK: - TargetTimePickerView

struct TargetTimePickerView: View {
    @Binding var targetTime: TimeInterval
    @State private var hours: Int = 4
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Target Marathon Time") {
                HStack {
                    Picker("Hours", selection: $hours) {
                        ForEach(2...6, id: \.self) { Text("\($0)h").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 160)
            }

            Section {
                HStack {
                    Text("Selected Time")
                    Spacer()
                    Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Target Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hours = Int(targetTime) / 3600
            minutes = (Int(targetTime) % 3600) / 60
            seconds = Int(targetTime) % 60
        }
        .onChange(of: hours) { _ in updateTime() }
        .onChange(of: minutes) { _ in updateTime() }
        .onChange(of: seconds) { _ in updateTime() }
    }

    private func updateTime() {
        targetTime = TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }
}
