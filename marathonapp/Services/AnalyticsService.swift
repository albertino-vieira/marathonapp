import Foundation

// MARK: - AnalyticsService
//
// Implements Training Load / ATL / CTL / TSB (similar to TrainingPeaks PMC)
// and marathon time prediction using the Riegel formula.

final class AnalyticsService {
    static let shared = AnalyticsService()

    // MARK: - Weekly Stats

    func buildWeeklyStats(from workouts: [RunWorkout], numberOfWeeks: Int = 12) -> [WeeklyStats] {
        let cal = Calendar.current
        let today = Date()
        var stats: [WeeklyStats] = []

        for offset in (0..<numberOfWeeks).reversed() {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: startOfWeek(today)),
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)
            else { continue }

            let weekWorkouts = workouts.filter {
                $0.date >= weekStart && $0.date <= weekEnd
            }

            let totalDist = weekWorkouts.reduce(0.0) { $0 + $1.distanceKm }
            let totalDuration = weekWorkouts.reduce(0.0) { $0 + $1.duration }
            let avgPace: Double
            if totalDist > 0 {
                avgPace = totalDuration / totalDist
            } else {
                avgPace = 0
            }
            let hrValues = weekWorkouts.compactMap { $0.averageHeartRate }
            let avgHR = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)
            let totalElevation = weekWorkouts.compactMap { $0.elevationGain }.reduce(0, +)
            let totalCal = weekWorkouts.compactMap { $0.calories }.reduce(0, +)
            let longRun = weekWorkouts.map { $0.distanceKm }.max() ?? 0

            stats.append(WeeklyStats(
                weekStart: weekStart,
                weekEnd: weekEnd,
                totalDistance: totalDist,
                totalDuration: totalDuration,
                workoutCount: weekWorkouts.count,
                averagePace: avgPace,
                averageHeartRate: avgHR,
                totalElevationGain: totalElevation > 0 ? totalElevation : nil,
                totalCalories: totalCal > 0 ? totalCal : nil,
                longRunDistance: longRun
            ))
        }
        return stats
    }

    // MARK: - Training Load (CTL/ATL/TSB)
    //
    // Each workout gets a Training Stress Score (TSS) proxy based on
    // duration, pace, and heart rate zone.
    // CTL (Chronic Training Load) = 42-day rolling average TSS → "Fitness"
    // ATL (Acute Training Load)   = 7-day rolling average TSS  → "Fatigue"
    // TSB (Training Stress Balance) = CTL - ATL                → "Form"

    func computeReadiness(from workouts: [RunWorkout], profile: RunnerProfile) -> MarathonReadiness {
        let tssPerDay = buildDailyTSS(from: workouts)
        let ctlHistory = rollingAverage(of: tssPerDay, days: 42)
        let atlHistory = rollingAverage(of: tssPerDay, days: 7)

        let ctl = ctlHistory.last ?? 0
        let atl = atlHistory.last ?? 0
        let tsb = ctl - atl

        // Normalize to 0-100 readiness score
        // TSB range: -50 (very fatigued) to +25 (peaked)
        let normalizedTSB = min(max((tsb + 50) / 75 * 100, 0), 100)

        let fitnessScore = min(ctl / 1.5, 100)
        let fatigueScore = min(atl / 1.2, 100)

        let alerts = generateAlerts(
            workouts: workouts,
            ctl: ctl,
            atl: atl,
            tsb: tsb,
            profile: profile
        )

        let suggestedSession = suggestTodaySession(tsb: tsb, workouts: workouts, profile: profile)
        let recommendation = buildRecommendation(tsb: tsb, ctl: ctl, profile: profile)
        let predictedTime = predictMarathonTime(from: workouts, profile: profile)

        return MarathonReadiness(
            score: normalizedTSB,
            fatigue: fatigueScore,
            fitness: fitnessScore,
            form: tsb,
            recommendation: recommendation,
            suggestedTodaySession: suggestedSession,
            alerts: alerts,
            predictedMarathonTime: predictedTime
        )
    }

    // MARK: - TSS Calculation

    private func buildDailyTSS(from workouts: [RunWorkout]) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for workout in workouts {
            let day = Calendar.current.startOfDay(for: workout.date)
            let tss = computeTSS(workout: workout)
            result[day, default: 0] += tss
        }
        return result
    }

    private func computeTSS(workout: RunWorkout) -> Double {
        // TSS proxy: duration(h) * intensity² * 100
        // intensity is based on pace zone relative to threshold pace (~5:00/km → 300 sec/km)
        let durationHours = workout.duration / 3600
        let thresholdPace: Double = 300  // 5:00/km
        let intensity: Double
        if workout.averagePace > 0 {
            intensity = thresholdPace / workout.averagePace  // >1 = faster than threshold
        } else {
            intensity = 0.6
        }
        return durationHours * pow(intensity, 2) * 100
    }

    private func rollingAverage(of dailyValues: [Date: Double], days: Int) -> [Double] {
        let cal = Calendar.current
        let sortedDates = dailyValues.keys.sorted()
        guard let earliest = sortedDates.first, let latest = sortedDates.last else { return [0] }

        var results: [Double] = []
        var currentDate = earliest
        var currentValue = 0.0

        // Exponential weighted moving average: today_value = yesterday_value + (tss - yesterday_value) / days
        while currentDate <= latest {
            let tss = dailyValues[currentDate] ?? 0
            currentValue = currentValue + (tss - currentValue) / Double(days)
            results.append(currentValue)
            currentDate = cal.date(byAdding: .day, value: 1, to: currentDate) ?? latest
        }
        return results
    }

    // MARK: - Alerts

    private func generateAlerts(
        workouts: [RunWorkout],
        ctl: Double,
        atl: Double,
        tsb: Double,
        profile: RunnerProfile
    ) -> [TrainingAlert] {
        var alerts: [TrainingAlert] = []

        // Overtraining risk: ATL >> CTL
        if atl > ctl * 1.5 && atl > 80 {
            alerts.append(TrainingAlert(
                type: .overtraining,
                message: "Your acute fatigue is significantly higher than fitness. Consider 1-2 rest days.",
                severity: .critical
            ))
        }

        // Rapid volume increase (>10% rule)
        let recentWeeks = buildWeeklyStats(from: workouts, numberOfWeeks: 3)
        if recentWeeks.count >= 2 {
            let thisWeek = recentWeeks.last?.totalDistance ?? 0
            let lastWeek = recentWeeks.dropLast().last?.totalDistance ?? 0
            if lastWeek > 0 && thisWeek > lastWeek * 1.15 {
                alerts.append(TrainingAlert(
                    type: .rapidVolumeIncrease,
                    message: "This week's volume is \(Int((thisWeek/lastWeek - 1) * 100))% higher than last week. Stick to the 10% rule.",
                    severity: .warning
                ))
            }
        }

        // Missing long run in last 2 weeks
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
        let recentLongRun = workouts
            .filter { $0.date >= twoWeeksAgo && $0.workoutType == .longRun }
            .max(by: { $0.distanceKm < $1.distanceKm })
        if recentLongRun == nil && ctl > 30 {
            alerts.append(TrainingAlert(
                type: .missingLongRun,
                message: "No long run in the last 2 weeks. The long run is key for marathon preparation.",
                severity: .warning
            ))
        }

        // Race approaching
        if let days = profile.daysUntilMarathon {
            if days <= 14 && days > 0 {
                alerts.append(TrainingAlert(
                    type: .raceApproaching,
                    message: "Marathon in \(days) days. Focus on tapering and rest.",
                    severity: .info
                ))
            }
            if days <= 7 && days > 0 {
                alerts.append(TrainingAlert(
                    type: .taperingReminder,
                    message: "Race week! Keep runs short and easy. Trust your training.",
                    severity: .info
                ))
            }
        }

        // Consistency drop
        let sixWeeks = buildWeeklyStats(from: workouts, numberOfWeeks: 6)
        let activeWeeks = sixWeeks.filter { $0.workoutCount > 0 }.count
        if activeWeeks < 3 {
            alerts.append(TrainingAlert(
                type: .consistencyDrop,
                message: "Only \(activeWeeks) active training weeks in the last 6. Consistency is key.",
                severity: .warning
            ))
        }

        return alerts
    }

    // MARK: - Session Suggestion

    private func suggestTodaySession(
        tsb: Double,
        workouts: [RunWorkout],
        profile: RunnerProfile
    ) -> SessionType {
        // Check last workout
        let lastWorkout = workouts.sorted(by: { $0.date > $1.date }).first
        let daysSinceLastRun = lastWorkout.map {
            Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0
        } ?? 99

        // Race week
        if let days = profile.daysUntilMarathon, days <= 7 { return .rest }

        // Very fatigued
        if tsb < -30 { return .rest }
        if tsb < -15 { return .recovery }

        // Check if long run is needed this week
        let thisWeekWorkouts = workoutsThisWeek(workouts)
        let hasLongRun = thisWeekWorkouts.contains { $0.workoutType == .longRun }
        let weeklyKm = thisWeekWorkouts.reduce(0.0) { $0 + $1.distanceKm }

        // Day scheduling logic
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 7:  // Saturday = Long Run day
            if !hasLongRun && tsb > -10 { return .longRun }
        case 3, 5:  // Tuesday, Thursday = Quality sessions
            if tsb > 0 { return .tempo }
            if tsb > -10 { return .intervals }
        default:
            break
        }

        if daysSinceLastRun == 0 { return .rest }
        if daysSinceLastRun >= 2 { return .easy }
        return .recovery
    }

    private func workoutsThisWeek(_ workouts: [RunWorkout]) -> [RunWorkout] {
        let start = startOfWeek(Date())
        return workouts.filter { $0.date >= start }
    }

    // MARK: - Recommendation Text

    private func buildRecommendation(tsb: Double, ctl: Double, profile: RunnerProfile) -> String {
        if let days = profile.daysUntilMarathon, days <= 7 {
            return "Race week! Stay relaxed, keep runs light, and prepare mentally."
        }
        if tsb < -30 {
            return "You're heavily fatigued. Take 1-2 full rest days before your next session."
        }
        if tsb < -15 {
            return "Moderate fatigue detected. A recovery run or rest day will help you absorb recent training."
        }
        if tsb > 20 {
            return "You're well rested and in great form. Consider a quality workout or long run today."
        }
        if ctl < 30 {
            return "Build your aerobic base with consistent easy runs before adding quality work."
        }
        return "Good training balance. Keep up with your planned sessions."
    }

    // MARK: - Marathon Time Prediction

    /// Uses Riegel formula: T2 = T1 × (D2/D1)^1.06
    /// and also VO2max estimation from recent tempo/race paces.
    func predictMarathonTime(from workouts: [RunWorkout], profile: RunnerProfile) -> TimeInterval? {
        let recentWorkouts = workouts.prefix(30)

        // Find best recent race-like effort (tempo or race, 5km+)
        let qualityWorkouts = recentWorkouts.filter {
            ($0.workoutType == .tempo || $0.workoutType == .race || $0.workoutType == .intervals)
            && $0.distanceKm >= 5
        }

        guard let best = qualityWorkouts.sorted(by: { $0.averagePace < $1.averagePace }).first
        else {
            // Fall back to best average pace from easy runs (conservative estimate)
            guard let anyWorkout = workouts.filter({ $0.distanceKm >= 5 }).min(by: { $0.averagePace < $1.averagePace })
            else { return nil }
            return riegelPrediction(fromDistance: anyWorkout.distanceKm, time: anyWorkout.duration, toDistance: 42.195)
        }

        return riegelPrediction(fromDistance: best.distanceKm, time: best.duration, toDistance: 42.195)
    }

    private func riegelPrediction(fromDistance d1: Double, time t1: TimeInterval, toDistance d2: Double) -> TimeInterval {
        t1 * pow(d2 / d1, 1.06)
    }

    // MARK: - Personal Records

    func computePersonalRecords(from workouts: [RunWorkout]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []

        let targets: [(PRType, Double)] = [
            (.fastestKm, 1.0),
            (.fastest5k, 5.0),
            (.fastest10k, 10.0),
            (.fastestHalfMarathon, 21.0975),
            (.fastestMarathon, 42.195)
        ]

        for (type, targetKm) in targets {
            let applicable = workouts.filter { $0.distanceKm >= targetKm }
            guard let best = applicable.min(by: { bestPaceForDistance($0, km: targetKm) < bestPaceForDistance($1, km: targetKm) })
            else { continue }
            let time = riegelPrediction(fromDistance: best.distanceKm, time: best.duration, toDistance: targetKm)
            records.append(PersonalRecord(type: type, value: time, date: best.date, workoutId: best.id))
        }

        if let longest = workouts.max(by: { $0.distanceKm < $1.distanceKm }) {
            records.append(PersonalRecord(type: .longestRun, value: longest.distanceKm, date: longest.date, workoutId: longest.id))
        }

        let weekly = buildWeeklyStats(from: workouts, numberOfWeeks: 52)
        if let bestWeek = weekly.max(by: { $0.totalDistance < $1.totalDistance }), bestWeek.totalDistance > 0 {
            records.append(PersonalRecord(type: .highestWeeklyVolume, value: bestWeek.totalDistance, date: bestWeek.weekStart))
        }

        return records
    }

    private func bestPaceForDistance(_ workout: RunWorkout, km: Double) -> Double {
        // If workout covers full distance, predict time using Riegel
        riegelPrediction(fromDistance: workout.distanceKm, time: workout.duration, toDistance: km)
    }

    // MARK: - Plan Generator

    func generateTrainingPlan(profile: RunnerProfile) -> TrainingPlan? {
        guard let marathonDate = profile.marathonDate else { return nil }
        let today = Date()
        let cal = Calendar.current
        let weeksAvailable = max(
            cal.dateComponents([.weekOfYear], from: today, to: marathonDate).weekOfYear ?? 0,
            4
        )
        let planWeeks = min(weeksAvailable, 18)

        var weeks: [TrainingWeek] = []
        let peakKm = profile.fitnessLevel.weeklyVolumePeak

        for w in 0..<planWeeks {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: w, to: startOfWeek(today)),
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)
            else { continue }

            let progress = Double(w) / Double(planWeeks)
            let (weekType, targetKm) = weekTypeAndVolume(
                weekIndex: w,
                totalWeeks: planWeeks,
                peakKm: peakKm,
                progress: progress
            )

            let days = buildWeekDays(weekStart: weekStart, weekType: weekType, targetKm: targetKm, profile: profile)

            weeks.append(TrainingWeek(
                weekNumber: w + 1,
                startDate: weekStart,
                endDate: weekEnd,
                days: days,
                weekType: weekType,
                targetDistance: targetKm
            ))
        }

        return TrainingPlan(
            name: "Marathon \(formattedDate(marathonDate))",
            marathonDate: marathonDate,
            fitnessLevel: profile.fitnessLevel,
            targetTime: profile.targetMarathonTime,
            weeks: weeks
        )
    }

    private func weekTypeAndVolume(
        weekIndex: Int,
        totalWeeks: Int,
        peakKm: Double,
        progress: Double
    ) -> (WeekType, Double) {
        let weeksFromEnd = totalWeeks - weekIndex

        if weeksFromEnd == 1 { return (.race, 15) }
        if weeksFromEnd <= 3 { return (.taper, peakKm * (0.5 + Double(weeksFromEnd - 1) * 0.15)) }
        if weeksFromEnd == 4 { return (.peak, peakKm) }

        // Every 4th week is recovery
        if (weekIndex + 1) % 4 == 0 { return (.recovery, peakKm * 0.7) }

        // Build phase
        let buildProgress = min(progress * 1.5, 1.0)
        if buildProgress < 0.4 {
            return (.base, peakKm * (0.5 + buildProgress))
        }
        return (.build, peakKm * (0.7 + buildProgress * 0.3))
    }

    private func buildWeekDays(
        weekStart: Date,
        weekType: WeekType,
        targetKm: Double,
        profile: RunnerProfile
    ) -> [TrainingDay] {
        let cal = Calendar.current
        var days: [TrainingDay] = []

        // Template: Mon-Sun sessions
        let weekTemplate: [SessionType]
        switch weekType {
        case .race:
            weekTemplate = [.easy, .rest, .easy, .rest, .rest, .easy, .race]
        case .taper:
            weekTemplate = [.easy, .rest, .tempo, .easy, .rest, .easy, .longRun]
        case .peak:
            weekTemplate = [.easy, .intervals, .easy, .tempo, .rest, .easy, .longRun]
        case .build:
            weekTemplate = [.easy, .intervals, .easy, .tempo, .rest, .strides, .longRun]
        case .base:
            weekTemplate = [.easy, .easy, .rest, .easy, .rest, .easy, .longRun]
        case .recovery:
            weekTemplate = [.recovery, .rest, .easy, .recovery, .rest, .easy, .easy]
        }

        for (i, sessionType) in weekTemplate.enumerated() {
            guard let date = cal.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let (dist, desc) = sessionDetails(
                type: sessionType,
                weekKm: targetKm,
                index: i,
                profile: profile
            )
            days.append(TrainingDay(
                date: date,
                sessionType: sessionType,
                targetDistance: dist,
                description: desc
            ))
        }
        return days
    }

    private func sessionDetails(
        type: SessionType,
        weekKm: Double,
        index: Int,
        profile: RunnerProfile
    ) -> (Double?, String) {
        switch type {
        case .rest:
            return (nil, "Full rest day. Focus on nutrition and sleep.")
        case .recovery:
            return (6, "Easy 6km at conversational pace. HR zone 1-2.")
        case .easy:
            let dist = min(weekKm * 0.15, 12)
            return (dist, "Easy run at comfortable pace. HR zone 2.")
        case .tempo:
            return (10, "10km with 4km at threshold pace (zone 4). Warm up + cool down.")
        case .intervals:
            return (10, "6×1km at 5K pace with 90sec recovery. Warm up + cool down.")
        case .strides:
            return (8, "8km easy with 6×20sec strides at mile pace.")
        case .longRun:
            let dist = min(weekKm * 0.35, 32)
            return (dist, "Long run at easy/marathon pace. Key session of the week.")
        case .race:
            return (42.195, "Race day! Execute your plan. Trust your training.")
        case .crossTraining:
            return (nil, "45min low-impact cross training: cycling, swimming, or yoga.")
        }
    }

    // MARK: - Helpers

    private func startOfWeek(_ date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        return fmt.string(from: date)
    }
}
