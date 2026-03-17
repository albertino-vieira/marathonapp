import Foundation

// MARK: - DataStore
//
// Persists workouts, profile, and plan using UserDefaults (JSON encoded).
// Suitable for MVP. Can be swapped for Core Data / SwiftData in a later phase.

@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var workouts: [RunWorkout] = []
    @Published var profile: RunnerProfile = RunnerProfile()
    @Published var trainingPlan: TrainingPlan?
    @Published var personalRecords: [PersonalRecord] = []
    @Published var weeklyGoals: [WeeklyGoal] = []

    // MARK: - Keys

    private enum Keys: String {
        case workouts, profile, trainingPlan, personalRecords, weeklyGoals
    }

    // MARK: - Init

    init() {
        loadAll()
    }

    // MARK: - Load

    private func loadAll() {
        workouts = load([RunWorkout].self, key: .workouts) ?? []
        profile = load(RunnerProfile.self, key: .profile) ?? RunnerProfile()
        trainingPlan = load(TrainingPlan.self, key: .trainingPlan)
        personalRecords = load([PersonalRecord].self, key: .personalRecords) ?? []
        weeklyGoals = load([WeeklyGoal].self, key: .weeklyGoals) ?? []
    }

    private func load<T: Decodable>(_ type: T.Type, key: Keys) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    // MARK: - Save

    func saveWorkouts() {
        save(workouts, key: .workouts)
    }

    func saveProfile() {
        save(profile, key: .profile)
    }

    func savePlan() {
        save(trainingPlan, key: .trainingPlan)
    }

    func savePersonalRecords() {
        save(personalRecords, key: .personalRecords)
    }

    func saveWeeklyGoals() {
        save(weeklyGoals, key: .weeklyGoals)
    }

    private func save<T: Encodable>(_ value: T, key: Keys) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    // MARK: - Merge HealthKit workouts

    /// Merges new workouts from HealthKit, skipping duplicates by healthKitUUID.
    func mergeWorkouts(_ newWorkouts: [RunWorkout]) {
        let existingUUIDs = Set(workouts.compactMap { $0.healthKitUUID })
        let toAdd = newWorkouts.filter { w in
            guard let uuid = w.healthKitUUID else { return true }
            return !existingUUIDs.contains(uuid)
        }
        workouts.append(contentsOf: toAdd)
        workouts.sort(by: { $0.date > $1.date })
        saveWorkouts()
    }

    // MARK: - Weekly Goals

    func currentWeekGoal() -> WeeklyGoal? {
        let start = startOfWeek(Date())
        return weeklyGoals.first { $0.weekStart == start }
    }

    func upsertWeeklyGoal(_ goal: WeeklyGoal) {
        if let idx = weeklyGoals.firstIndex(where: { $0.weekStart == goal.weekStart }) {
            weeklyGoals[idx] = goal
        } else {
            weeklyGoals.append(goal)
        }
        saveWeeklyGoals()
    }

    func updateWeeklyGoalProgress() {
        let start = startOfWeek(Date())
        let thisWeekWorkouts = workouts.filter { $0.date >= start }
        let achievedKm = thisWeekWorkouts.reduce(0.0) { $0 + $1.distanceKm }
        let achievedSessions = thisWeekWorkouts.count

        if let idx = weeklyGoals.firstIndex(where: { $0.weekStart == start }) {
            weeklyGoals[idx].achievedDistance = achievedKm
            weeklyGoals[idx].achievedSessions = achievedSessions
        } else {
            var goal = WeeklyGoal(
                weekStart: start,
                targetDistance: profile.weeklyGoalKm,
                targetSessions: profile.weeklyGoalSessions
            )
            goal.achievedDistance = achievedKm
            goal.achievedSessions = achievedSessions
            weeklyGoals.append(goal)
        }
        saveWeeklyGoals()
    }

    // MARK: - Plan Management

    func markDayCompleted(planId: UUID, weekId: UUID, dayId: UUID, workout: RunWorkout?) {
        guard trainingPlan?.id == planId,
              let wIdx = trainingPlan?.weeks.firstIndex(where: { $0.id == weekId }),
              let dIdx = trainingPlan?.weeks[wIdx].days.firstIndex(where: { $0.id == dayId })
        else { return }

        trainingPlan?.weeks[wIdx].days[dIdx].isCompleted = true
        trainingPlan?.weeks[wIdx].days[dIdx].completedWorkout = workout
        savePlan()
    }

    // MARK: - Helpers

    private func startOfWeek(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}
