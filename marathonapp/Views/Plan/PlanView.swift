import SwiftUI

// MARK: - PlanView

struct PlanView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedWeekIndex = 0

    var body: some View {
        NavigationView {
            Group {
                if let plan = vm.trainingPlan {
                    planContent(plan)
                } else {
                    noPlanView
                }
            }
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if vm.trainingPlan != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            vm.regeneratePlan()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plan Content

    private func planContent(_ plan: TrainingPlan) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                planHeader(plan)
                weekSelector(plan)
                if plan.weeks.indices.contains(selectedWeekIndex) {
                    weekDetail(plan.weeks[selectedWeekIndex])
                }
                upcomingWeeks(plan)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func planHeader(_ plan: TrainingPlan) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    if let target = plan.formattedTargetTime {
                        Label("Target: \(target)", systemImage: "flag.checkered")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    Text("\(plan.weeksUntilMarathon) weeks remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", plan.completionPercentage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            ProgressBar(
                progress: plan.completionPercentage / 100,
                color: .blue,
                height: 10
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricBadge(label: "Total Weeks", value: "\(plan.totalWeeks)", color: .blue)
                MetricBadge(label: "Done", value: "\(plan.completedWeeks)", color: .green)
                MetricBadge(label: "Remaining", value: "\(plan.totalWeeks - plan.completedWeeks)", color: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func weekSelector(_ plan: TrainingPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(plan.weeks.indices, id: \.self) { idx in
                    let week = plan.weeks[idx]
                    Button {
                        selectedWeekIndex = idx
                    } label: {
                        VStack(spacing: 4) {
                            Text("W\(week.weekNumber)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Circle()
                                .fill(weekColor(week, selected: selectedWeekIndex == idx))
                                .frame(width: 10, height: 10)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedWeekIndex == idx
                            ? Color.accentColor
                            : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundColor(selectedWeekIndex == idx ? .white : .primary)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func weekColor(_ week: TrainingWeek, selected: Bool) -> Color {
        if selected { return .white }
        if week.isCompleted { return .green }
        return Color(week.weekType.color)
    }

    private func weekDetail(_ week: TrainingWeek) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Week \(week.weekNumber)")
                            .font(.headline)
                        weekTypeBadge(week.weekType)
                    }
                    Text(week.startDate.formatted(.dateTime.day().month()) + " – " + week.endDate.formatted(.dateTime.day().month()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f km", week.targetDistance))
                        .font(.headline)
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            ProgressBar(progress: week.progressPercentage / 100, color: Color(week.weekType.color))
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(week.days) { day in
                    TrainingDayRow(day: day) {
                        vm.markDayCompleted(weekId: week.id, dayId: day.id)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func weekTypeBadge(_ type: WeekType) -> some View {
        Text(type.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color(type.color))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(type.color).opacity(0.15))
            .cornerRadius(6)
    }

    private func upcomingWeeks(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "All Weeks")
            ForEach(plan.weeks) { week in
                weekSummaryRow(week)
            }
            .padding(.horizontal)
        }
    }

    private func weekSummaryRow(_ week: TrainingWeek) -> some View {
        HStack {
            Text("W\(week.weekNumber)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .frame(width: 30)
                .foregroundColor(Color(week.weekType.color))

            VStack(alignment: .leading, spacing: 2) {
                Text(week.weekType.rawValue)
                    .font(.subheadline)
                Text(week.startDate.formatted(.dateTime.day().month()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f km", week.targetDistance))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if week.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - No Plan View

    private var noPlanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("No Training Plan")
                .font(.title2)
                .fontWeight(.bold)

            Text("Set your marathon date in Settings to generate a personalised training plan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                vm.regeneratePlan()
            } label: {
                Label("Generate Plan", systemImage: "wand.and.stars")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.profile.marathonDate == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TrainingDayRow

struct TrainingDayRow: View {
    let day: TrainingDay
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Day
            VStack(spacing: 1) {
                Text(day.dayOfWeek)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(width: 32)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(day.sessionType.color).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: day.sessionType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(day.sessionType.color))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(day.sessionType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(day.skipped)
                Text(day.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                if let dist = day.targetDistance {
                    Text(String(format: "%.1f km", dist))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(day.sessionType.color))
                }
            }

            Spacer()

            // Status
            if day.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else if day.sessionType != .rest && Calendar.current.isDateInPast(day.date) {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            day.isCompleted
            ? Color.green.opacity(0.08)
            : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(12)
        .opacity(day.skipped ? 0.5 : 1.0)
    }
}

private extension Date {
    var isDateInPast: Bool { self < Date() }
}
private extension Calendar {
    func isDateInPast(_ date: Date) -> Bool { date < Date() }
}
