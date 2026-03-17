import Foundation

// MARK: - RunnerProfile

struct RunnerProfile: Codable {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int?
    var maxHeartRate: Int?             // bpm, nil = auto (220 - age)
    var restingHeartRate: Int?         // bpm
    var fitnessLevel: FitnessLevel = .beginner
    var marathonDate: Date?
    var targetMarathonTime: TimeInterval?
    var weeklyGoalKm: Double = 40
    var weeklyGoalSessions: Int = 4
    var onboardingCompleted: Bool = false
    var createdAt: Date = Date()

    var effectiveMaxHR: Int {
        if let hr = maxHeartRate { return hr }
        if let a = age { return 220 - a }
        return 180
    }

    var formattedTargetTime: String? {
        guard let t = targetMarathonTime else { return nil }
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    var daysUntilMarathon: Int? {
        guard let date = marathonDate else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: Date(), to: date)
        return comps.day
    }

    var weeksUntilMarathon: Int? {
        guard let days = daysUntilMarathon else { return nil }
        return days / 7
    }
}

// MARK: - MarathonReadiness

struct MarathonReadiness {
    var score: Double            // 0-100
    var fatigue: Double          // 0-100 (higher = more fatigue)
    var fitness: Double          // 0-100 (higher = better fitness)
    var form: Double             // fitness - fatigue
    var recommendation: String
    var suggestedTodaySession: SessionType
    var alerts: [TrainingAlert]
    var predictedMarathonTime: TimeInterval?

    var readinessLabel: String {
        switch score {
        case 80...100: return "Peak"
        case 60..<80:  return "Good"
        case 40..<60:  return "Moderate"
        case 20..<40:  return "Tired"
        default:       return "Fatigued"
        }
    }

    var readinessColor: String {
        switch score {
        case 80...100: return "green"
        case 60..<80:  return "blue"
        case 40..<60:  return "yellow"
        case 20..<40:  return "orange"
        default:       return "red"
        }
    }

    var formattedPredictedTime: String? {
        guard let t = predictedMarathonTime else { return nil }
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

// MARK: - TrainingAlert

struct TrainingAlert: Identifiable {
    var id: UUID = UUID()
    var type: AlertType
    var message: String
    var severity: AlertSeverity
}

enum AlertType: String {
    case overtraining = "Overtraining Risk"
    case undertraining = "Undertraining"
    case missingLongRun = "Missing Long Run"
    case highHeartRate = "High Heart Rate"
    case rapidVolumeIncrease = "Rapid Volume Increase"
    case consistencyDrop = "Consistency Drop"
    case taperingReminder = "Tapering"
    case raceApproaching = "Race Approaching"
}

enum AlertSeverity: String {
    case info = "info"
    case warning = "warning"
    case critical = "critical"

    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}
