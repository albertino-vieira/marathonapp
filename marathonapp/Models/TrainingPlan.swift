import Foundation

// MARK: - TrainingPlan

struct TrainingPlan: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var marathonDate: Date
    var createdAt: Date = Date()
    var fitnessLevel: FitnessLevel
    var targetTime: TimeInterval?    // target finish time in seconds
    var weeks: [TrainingWeek]
    var isActive: Bool = true

    var totalWeeks: Int { weeks.count }

    var completedWeeks: Int {
        weeks.filter { $0.isCompleted }.count
    }

    var completionPercentage: Double {
        guard totalWeeks > 0 else { return 0 }
        let completedDays = weeks.flatMap { $0.days }.filter { $0.isCompleted }.count
        let totalDays = weeks.flatMap { $0.days }.filter { $0.sessionType != .rest }.count
        guard totalDays > 0 else { return 0 }
        return Double(completedDays) / Double(totalDays) * 100
    }

    var weeksUntilMarathon: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.weekOfYear], from: Date(), to: marathonDate)
        return max(0, comps.weekOfYear ?? 0)
    }

    var formattedTargetTime: String? {
        guard let t = targetTime else { return nil }
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

// MARK: - FitnessLevel

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var description: String {
        switch self {
        case .beginner: return "Running < 3 months, up to 25km/week"
        case .intermediate: return "Running 6+ months, 30-50km/week"
        case .advanced: return "Running 1+ year, 50km+/week"
        }
    }

    var weeklyVolumePeak: Double {
        switch self {
        case .beginner: return 45
        case .intermediate: return 65
        case .advanced: return 90
        }
    }
}

// MARK: - TrainingWeek

struct TrainingWeek: Identifiable, Codable {
    var id: UUID = UUID()
    var weekNumber: Int
    var startDate: Date
    var endDate: Date
    var days: [TrainingDay]
    var weekType: WeekType
    var targetDistance: Double    // km

    var isCompleted: Bool {
        days.filter { $0.sessionType != .rest }.allSatisfy { $0.isCompleted }
    }

    var completedDistance: Double {
        days.compactMap { $0.completedWorkout?.distanceKm }.reduce(0, +)
    }

    var progressPercentage: Double {
        guard targetDistance > 0 else { return 0 }
        return min(completedDistance / targetDistance * 100, 100)
    }
}

enum WeekType: String, Codable, CaseIterable {
    case base = "Base"
    case build = "Build"
    case peak = "Peak"
    case taper = "Taper"
    case recovery = "Recovery"
    case race = "Race Week"

    var color: String {
        switch self {
        case .base: return "blue"
        case .build: return "orange"
        case .peak: return "red"
        case .taper: return "green"
        case .recovery: return "mint"
        case .race: return "purple"
        }
    }
}

// MARK: - TrainingDay

struct TrainingDay: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var sessionType: SessionType
    var targetDistance: Double?       // km
    var targetPace: Double?           // sec/km
    var description: String
    var completedWorkout: RunWorkout?
    var isCompleted: Bool = false
    var skipped: Bool = false

    var dayOfWeek: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        return fmt.string(from: date)
    }
}

enum SessionType: String, Codable, CaseIterable {
    case rest = "Rest"
    case easy = "Easy Run"
    case recovery = "Recovery Run"
    case tempo = "Tempo Run"
    case intervals = "Intervals"
    case longRun = "Long Run"
    case race = "Race"
    case crossTraining = "Cross Training"
    case strides = "Strides"

    var icon: String {
        switch self {
        case .rest: return "moon.zzz.fill"
        case .easy: return "figure.walk"
        case .recovery: return "leaf.fill"
        case .tempo: return "speedometer"
        case .intervals: return "bolt.fill"
        case .longRun: return "road.lanes"
        case .race: return "flag.checkered"
        case .crossTraining: return "figure.strengthtraining.traditional"
        case .strides: return "hare.fill"
        }
    }

    var color: String {
        switch self {
        case .rest: return "gray"
        case .easy: return "green"
        case .recovery: return "mint"
        case .tempo: return "orange"
        case .intervals: return "red"
        case .longRun: return "blue"
        case .race: return "purple"
        case .crossTraining: return "teal"
        case .strides: return "yellow"
        }
    }

    var isRun: Bool {
        self != .rest && self != .crossTraining
    }
}

// MARK: - WeeklyGoal

struct WeeklyGoal: Identifiable, Codable {
    var id: UUID = UUID()
    var weekStart: Date
    var targetDistance: Double      // km
    var targetSessions: Int
    var achievedDistance: Double = 0
    var achievedSessions: Int = 0

    var isAchieved: Bool {
        achievedDistance >= targetDistance && achievedSessions >= targetSessions
    }

    var distanceProgress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(achievedDistance / targetDistance, 1.0)
    }

    var sessionsProgress: Double {
        guard targetSessions > 0 else { return 0 }
        return min(Double(achievedSessions) / Double(targetSessions), 1.0)
    }
}
