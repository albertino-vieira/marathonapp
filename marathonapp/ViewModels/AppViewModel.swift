import Foundation
import SwiftUI

// MARK: - AppViewModel
//
// Central state coordinator. All screens observe this object.

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Services

    private let healthKit = HealthKitService.shared
    private let analytics = AnalyticsService.shared
    private let store = DataStore.shared

    // MARK: - Published State

    @Published var workouts: [RunWorkout] = []
    @Published var weeklyStats: [WeeklyStats] = []
    @Published var readiness: MarathonReadiness?
    @Published var personalRecords: [PersonalRecord] = []
    @Published var trainingPlan: TrainingPlan?
    @Published var profile: RunnerProfile = RunnerProfile()
    @Published var currentWeekGoal: WeeklyGoal?

    @Published var isLoading = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?
    @Published var showOnboarding = false

    // MARK: - Init

    init() {
        loadFromStore()
        if !profile.onboardingCompleted {
            showOnboarding = true
        }
    }

    // MARK: - Load local data

    func loadFromStore() {
        workouts = store.workouts
        profile = store.profile
        trainingPlan = store.trainingPlan
        personalRecords = store.personalRecords
        currentWeekGoal = store.currentWeekGoal()
        refreshDerivedData()
    }

    func refreshDerivedData() {
        weeklyStats = analytics.buildWeeklyStats(from: workouts, numberOfWeeks: 16)
        readiness = analytics.computeReadiness(from: workouts, profile: profile)
        personalRecords = analytics.computePersonalRecords(from: workouts)
        store.updateWeeklyGoalProgress()
        currentWeekGoal = store.currentWeekGoal()
    }

    // MARK: - HealthKit Sync

    func syncWithHealthKit() async {
        isLoading = true
        syncError = nil

        if healthKit.authorizationStatus == .notDetermined {
            await healthKit.requestAuthorization()
        }

        guard healthKit.authorizationStatus == .authorized else {
            syncError = "HealthKit access denied. Please enable in Settings > Health > Data Access."
            isLoading = false
            return
        }

        do {
            let fetched = try await healthKit.fetchRunningWorkouts(
                limit: 200,
                from: lastSyncDate
            )
            store.mergeWorkouts(fetched)
            workouts = store.workouts
            lastSyncDate = Date()
            refreshDerivedData()
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func requestHealthKitPermission() async {
        await healthKit.requestAuthorization()
    }

    // MARK: - Profile

    func saveProfile(_ updated: RunnerProfile) {
        store.profile = updated
        store.saveProfile()
        profile = updated
        refreshDerivedData()
    }

    func completeOnboarding(profile: RunnerProfile) {
        var p = profile
        p.onboardingCompleted = true
        saveProfile(p)
        showOnboarding = false

        if let plan = analytics.generateTrainingPlan(profile: p) {
            store.trainingPlan = plan
            store.savePlan()
            trainingPlan = plan
        }
    }

    // MARK: - Training Plan

    func regeneratePlan() {
        guard let plan = analytics.generateTrainingPlan(profile: profile) else { return }
        store.trainingPlan = plan
        store.savePlan()
        trainingPlan = plan
    }

    func markDayCompleted(weekId: UUID, dayId: UUID) {
        guard let planId = trainingPlan?.id else { return }
        let matchingWorkout = workouts.first { w in
            guard let day = trainingPlan?.weeks
                .first(where: { $0.id == weekId })?
                .days.first(where: { $0.id == dayId })
            else { return false }
            return Calendar.current.isDate(w.date, inSameDayAs: day.date)
        }
        store.markDayCompleted(planId: planId, weekId: weekId, dayId: dayId, workout: matchingWorkout)
        trainingPlan = store.trainingPlan
    }

    // MARK: - Weekly Goal

    func setWeeklyGoal(km: Double, sessions: Int) {
        let start = startOfWeek(Date())
        var goal = store.currentWeekGoal() ?? WeeklyGoal(
            weekStart: start,
            targetDistance: km,
            targetSessions: sessions
        )
        goal.targetDistance = km
        goal.targetSessions = sessions
        store.upsertWeeklyGoal(goal)
        currentWeekGoal = store.currentWeekGoal()
        profile.weeklyGoalKm = km
        profile.weeklyGoalSessions = sessions
        store.saveProfile()
    }

    // MARK: - Convenience

    var thisWeekWorkouts: [RunWorkout] {
        let start = startOfWeek(Date())
        return workouts.filter { $0.date >= start }
    }

    var thisWeekKm: Double {
        thisWeekWorkouts.reduce(0.0) { $0 + $1.distanceKm }
    }

    var longestRecentRun: RunWorkout? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { $0.date >= thirtyDaysAgo }.max(by: { $0.distanceKm < $1.distanceKm })
    }

    var recentTrend: Trend {
        guard weeklyStats.count >= 2 else { return .stable }
        let recent = weeklyStats.suffix(2)
        guard let prev = recent.first, let curr = recent.last else { return .stable }
        if curr.totalDistance > prev.totalDistance * 1.05 { return .improving }
        if curr.totalDistance < prev.totalDistance * 0.90 { return .declining }
        return .stable
    }

    enum Trend {
        case improving, stable, declining

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "minus"
            case .declining: return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .improving: return .green
            case .stable: return .blue
            case .declining: return .orange
            }
        }
    }

    // MARK: - Helpers

    private func startOfWeek(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}
