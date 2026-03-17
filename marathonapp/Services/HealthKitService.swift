import Foundation
import HealthKit

// MARK: - HealthKitService

/// Manages all HealthKit interactions: permissions, data fetch, and parsing.
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var lastSyncDate: Date?

    // MARK: - Types to read

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning,
            .heartRate,
            .runningPower,
            .runningSpeed,
            .stepCount,
            .basalEnergyBurned,
            .activeEnergyBurned,
            .flightsClimbed
        ]
        for id in quantityTypes {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let cadence = HKObjectType.quantityType(forIdentifier: .runningStrideLength) {
            types.insert(cadence)
        }
        return types
    }

    // MARK: - Authorization

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .denied
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
        }
    }

    func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .denied
            return
        }
        let status = store.authorizationStatus(for: HKObjectType.workoutType())
        switch status {
        case .sharingAuthorized, .notDetermined:
            authorizationStatus = .authorized
        case .sharingDenied:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    // MARK: - Fetch Running Workouts

    func fetchRunningWorkouts(limit: Int = 200, from startDate: Date? = nil) async throws -> [RunWorkout] {
        let workoutType = HKWorkoutType.workoutType()
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)

        var predicates: [NSPredicate] = [runningPredicate]
        if let start = startDate {
            predicates.append(HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate))
        }

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compound,
                limit: limit,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let self, let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                Task {
                    var runWorkouts: [RunWorkout] = []
                    for hkWorkout in workouts {
                        if let run = await self.parseWorkout(hkWorkout) {
                            runWorkouts.append(run)
                        }
                    }
                    continuation.resume(returning: runWorkouts)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Parse HKWorkout → RunWorkout

    private func parseWorkout(_ workout: HKWorkout) async -> RunWorkout? {
        let duration = workout.duration
        let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0

        guard distance > 100 else { return nil }  // skip very short samples

        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        let avgHR = await fetchAverageQuantity(
            for: .heartRate,
            workout: workout,
            unit: HKUnit(from: "count/min")
        )
        let maxHR = await fetchMaxQuantity(
            for: .heartRate,
            workout: workout,
            unit: HKUnit(from: "count/min")
        )
        let avgCadence = await fetchAverageCadence(workout: workout)
        let (gain, loss) = await fetchElevation(workout: workout)
        let splits = await fetchKmSplits(workout: workout)

        let paceSecPerKm: Double
        if distance > 0 {
            paceSecPerKm = duration / (distance / 1000)
        } else {
            paceSecPerKm = 0
        }

        let workoutType = classifyWorkout(
            distance: distance / 1000,
            pace: paceSecPerKm,
            avgHR: avgHR,
            splits: splits
        )

        return RunWorkout(
            id: UUID(),
            date: workout.startDate,
            duration: duration,
            distance: distance,
            averagePace: paceSecPerKm,
            kmSplits: splits,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            averageCadence: avgCadence,
            elevationGain: gain,
            elevationLoss: loss,
            calories: calories,
            workoutType: workoutType,
            healthKitUUID: workout.uuid.uuidString
        )
    }

    // MARK: - Helpers

    private func fetchAverageQuantity(
        for identifier: HKQuantityTypeIdentifier,
        workout: HKWorkout,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchMaxQuantity(
        for identifier: HKQuantityTypeIdentifier,
        workout: HKWorkout,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, stats, _ in
                continuation.resume(returning: stats?.maximumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchAverageCadence(workout: HKWorkout) async -> Double? {
        // Step count over duration → steps/min
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                guard let steps = stats?.sumQuantity()?.doubleValue(for: .count()) else {
                    continuation.resume(returning: nil)
                    return
                }
                let minutes = workout.duration / 60
                guard minutes > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: steps / minutes)
            }
            store.execute(query)
        }
    }

    private func fetchElevation(workout: HKWorkout) async -> (gain: Double?, loss: Double?) {
        // flights climbed as proxy for elevation gain
        guard let type = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
            return (nil, nil)
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let gain: Double? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                // 1 flight ≈ 3m
                if let flights = stats?.sumQuantity()?.doubleValue(for: .count()) {
                    continuation.resume(returning: flights * 3.0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }
        return (gain, nil)
    }

    private func fetchKmSplits(workout: HKWorkout) async -> [KmSplit] {
        guard let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        // Fetch distance samples
        let distanceSamples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: distType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        let hrSamples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        return buildKmSplits(
            distanceSamples: distanceSamples,
            hrSamples: hrSamples,
            workoutStart: workout.startDate
        )
    }

    private func buildKmSplits(
        distanceSamples: [HKQuantitySample],
        hrSamples: [HKQuantitySample],
        workoutStart: Date
    ) -> [KmSplit] {
        var splits: [KmSplit] = []
        var accumulatedDistance = 0.0
        var currentKm = 1
        var splitStartTime = workoutStart
        var samplesInSplit: [HKQuantitySample] = []

        for sample in distanceSamples {
            let dist = sample.quantity.doubleValue(for: .meter())
            accumulatedDistance += dist
            samplesInSplit.append(sample)

            if accumulatedDistance >= Double(currentKm) * 1000 {
                let splitEndTime = sample.endDate
                let duration = splitEndTime.timeIntervalSince(splitStartTime)
                let pace = duration  // sec/km since each split is exactly 1km

                let avgHR = averageHR(from: hrSamples, start: splitStartTime, end: splitEndTime)

                splits.append(KmSplit(
                    kilometer: currentKm,
                    pace: pace,
                    heartRate: avgHR
                ))

                currentKm += 1
                splitStartTime = splitEndTime
                samplesInSplit = []
            }
        }
        return splits
    }

    private func averageHR(from samples: [HKQuantitySample], start: Date, end: Date) -> Double? {
        let unit = HKUnit(from: "count/min")
        let relevant = samples.filter { $0.startDate >= start && $0.endDate <= end }
        guard !relevant.isEmpty else { return nil }
        let sum = relevant.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return sum / Double(relevant.count)
    }

    // MARK: - Classify Workout Type

    private func classifyWorkout(
        distance: Double,
        pace: Double,
        avgHR: Double?,
        splits: [KmSplit]
    ) -> WorkoutType {
        // Long Run: 15km+
        if distance >= 15 { return .longRun }

        // Intervals: high pace variance
        if splits.count >= 4 {
            let paces = splits.map { $0.pace }
            let mean = paces.reduce(0, +) / Double(paces.count)
            let variance = paces.map { pow($0 - mean, 2) }.reduce(0, +) / Double(paces.count)
            let stdDev = sqrt(variance)
            if stdDev > 30 { return .intervals }  // >30sec variance
        }

        // Tempo: faster pace, moderate HR
        if pace < 330 {  // faster than 5:30/km
            return .tempo
        }

        // Recovery: easy pace + short distance
        if pace > 420 && distance < 8 {  // slower than 7:00/km
            return .recovery
        }

        return .easy
    }
}
