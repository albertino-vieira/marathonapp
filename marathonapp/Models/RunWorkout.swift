import Foundation
import HealthKit

// MARK: - WorkoutType

enum WorkoutType: String, Codable, CaseIterable {
    case easy = "Easy Run"
    case recovery = "Recovery"
    case tempo = "Tempo"
    case intervals = "Intervals"
    case longRun = "Long Run"
    case race = "Race"
    case unknown = "Run"

    var icon: String {
        switch self {
        case .easy: return "figure.walk"
        case .recovery: return "leaf.fill"
        case .tempo: return "speedometer"
        case .intervals: return "bolt.fill"
        case .longRun: return "road.lanes"
        case .race: return "flag.checkered"
        case .unknown: return "figure.run"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .recovery: return "mint"
        case .tempo: return "orange"
        case .intervals: return "red"
        case .longRun: return "blue"
        case .race: return "purple"
        case .unknown: return "gray"
        }
    }
}

// MARK: - RunWorkout

struct RunWorkout: Identifiable, Codable {
    var id: UUID
    var date: Date
    var duration: TimeInterval        // seconds
    var distance: Double              // meters
    var averagePace: Double           // sec/km
    var kmSplits: [KmSplit]
    var averageHeartRate: Double?     // bpm
    var maxHeartRate: Double?         // bpm
    var averageCadence: Double?       // steps/min
    var elevationGain: Double?        // meters
    var elevationLoss: Double?        // meters
    var calories: Double?             // kcal
    var workoutType: WorkoutType
    var healthKitUUID: String?
    var notes: String?

    // MARK: Computed

    var distanceKm: Double { distance / 1000 }

    var formattedPace: String {
        let mins = Int(averagePace) / 60
        let secs = Int(averagePace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f km", distanceKm)
    }

    var heartRateZone: HeartRateZone? {
        guard let hr = averageHeartRate else { return nil }
        return HeartRateZone.zone(for: hr)
    }

    init(
        id: UUID = UUID(),
        date: Date,
        duration: TimeInterval,
        distance: Double,
        averagePace: Double,
        kmSplits: [KmSplit] = [],
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        averageCadence: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        calories: Double? = nil,
        workoutType: WorkoutType = .unknown,
        healthKitUUID: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.distance = distance
        self.averagePace = averagePace
        self.kmSplits = kmSplits
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageCadence = averageCadence
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.calories = calories
        self.workoutType = workoutType
        self.healthKitUUID = healthKitUUID
        self.notes = notes
    }
}

// MARK: - KmSplit

struct KmSplit: Identifiable, Codable {
    var id: UUID = UUID()
    var kilometer: Int
    var pace: Double          // sec/km
    var heartRate: Double?    // bpm
    var elevation: Double?    // meters

    var formattedPace: String {
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - HeartRateZone

enum HeartRateZone: Int, CaseIterable, Codable {
    case zone1 = 1
    case zone2 = 2
    case zone3 = 3
    case zone4 = 4
    case zone5 = 5

    var name: String {
        switch self {
        case .zone1: return "Z1 Recovery"
        case .zone2: return "Z2 Aerobic"
        case .zone3: return "Z3 Tempo"
        case .zone4: return "Z4 Threshold"
        case .zone5: return "Z5 VO2max"
        }
    }

    var color: String {
        switch self {
        case .zone1: return "blue"
        case .zone2: return "green"
        case .zone3: return "yellow"
        case .zone4: return "orange"
        case .zone5: return "red"
        }
    }

    /// Approximate zone based on bpm (assumes max HR ~180)
    static func zone(for bpm: Double, maxHR: Double = 180) -> HeartRateZone {
        let pct = bpm / maxHR
        switch pct {
        case ..<0.60: return .zone1
        case 0.60..<0.70: return .zone2
        case 0.70..<0.80: return .zone3
        case 0.80..<0.90: return .zone4
        default: return .zone5
        }
    }
}

// MARK: - WeeklyStats

struct WeeklyStats: Identifiable, Codable {
    var id: UUID = UUID()
    var weekStart: Date
    var weekEnd: Date
    var totalDistance: Double       // km
    var totalDuration: TimeInterval
    var workoutCount: Int
    var averagePace: Double         // sec/km
    var averageHeartRate: Double?
    var totalElevationGain: Double?
    var totalCalories: Double?
    var longRunDistance: Double     // km

    var weekLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        return "\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd))"
    }

    var shortLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: weekStart)
    }

    static var empty: WeeklyStats {
        WeeklyStats(
            weekStart: Date(),
            weekEnd: Date(),
            totalDistance: 0,
            totalDuration: 0,
            workoutCount: 0,
            averagePace: 0,
            longRunDistance: 0
        )
    }
}

// MARK: - PersonalRecord

struct PersonalRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var type: PRType
    var value: Double
    var date: Date
    var workoutId: UUID?

    var formattedValue: String {
        switch type {
        case .fastestKm, .fastest5k, .fastest10k, .fastestHalfMarathon, .fastestMarathon:
            let mins = Int(value) / 60
            let secs = Int(value) % 60
            return String(format: "%d:%02d", mins, secs)
        case .longestRun:
            return String(format: "%.2f km", value)
        case .highestWeeklyVolume:
            return String(format: "%.1f km", value)
        }
    }
}

enum PRType: String, Codable, CaseIterable {
    case fastestKm = "Fastest 1km"
    case fastest5k = "Fastest 5km"
    case fastest10k = "Fastest 10km"
    case fastestHalfMarathon = "Fastest Half Marathon"
    case fastestMarathon = "Fastest Marathon"
    case longestRun = "Longest Run"
    case highestWeeklyVolume = "Highest Weekly Volume"

    var icon: String {
        switch self {
        case .fastestKm: return "1.circle.fill"
        case .fastest5k: return "5.circle.fill"
        case .fastest10k: return "10.circle.fill"
        case .fastestHalfMarathon: return "h.circle.fill"
        case .fastestMarathon: return "m.circle.fill"
        case .longestRun: return "arrow.right.to.line"
        case .highestWeeklyVolume: return "chart.bar.fill"
        }
    }
}
