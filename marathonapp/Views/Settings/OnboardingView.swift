import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var step = 0
    @State private var profile = RunnerProfile()
    @State private var isRequestingHK = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: step)
                    }
                }
                .padding(.top, 20)

                Spacer()

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: profileStep
                    case 2: marathonStep
                    case 3: healthKitStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation buttons
                HStack {
                    if step > 0 {
                        Button {
                            withAnimation { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button {
                        if step < 3 {
                            withAnimation { step += 1 }
                        } else {
                            vm.completeOnboarding(profile: profile)
                        }
                    } label: {
                        HStack {
                            Text(step == 3 ? "Get Started" : "Next")
                                .fontWeight(.semibold)
                            Image(systemName: step == 3 ? "checkmark" : "chevron.right")
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(isRequestingHK)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(.blue.gradient)
            Text("Welcome to\nMarathonApp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Your personal marathon coach.\nTrack runs, analyse performance, and conquer 42.195km.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us about yourself")
                .font(.title2)
                .fontWeight(.bold)
            VStack(spacing: 14) {
                FloatingTextField(label: "Your name", text: $profile.name)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Age").font(.caption).foregroundColor(.secondary)
                        TextField("e.g. 30", value: $profile.age, format: .number)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resting HR").font(.caption).foregroundColor(.secondary)
                        TextField("bpm", value: $profile.restingHeartRate, format: .number)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fitness Level").font(.caption).foregroundColor(.secondary)
                    Picker("Fitness Level", selection: $profile.fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { l in
                            Text(l.rawValue).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Text(profile.fitnessLevel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var marathonStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set your marathon goal")
                .font(.title2)
                .fontWeight(.bold)
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Marathon Date").font(.caption).foregroundColor(.secondary)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { profile.marathonDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())! },
                            set: { profile.marathonDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly km Goal").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text(String(format: "%.0f km/week", profile.weeklyGoalKm))
                            .font(.headline)
                        Spacer()
                    }
                    Slider(value: $profile.weeklyGoalKm, in: 10...120, step: 5)
                }

                HStack {
                    Text("Weekly Sessions").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Stepper("\(profile.weeklyGoalSessions) runs", value: $profile.weeklyGoalSessions, in: 2...7)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var healthKitStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red.gradient)
            Text("Connect Apple Health")
                .font(.title2)
                .fontWeight(.bold)
            Text("MarathonApp reads your running workouts from Apple Health to analyse your training data.\n\nNo data is shared with third parties.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                isRequestingHK = true
                Task {
                    await vm.requestHealthKitPermission()
                    isRequestingHK = false
                }
            } label: {
                Label("Connect HealthKit", systemImage: "heart.fill")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(14)
            }
            .disabled(isRequestingHK)
        }
    }
}

// MARK: - FloatingTextField

struct FloatingTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(label, text: $text)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
}
