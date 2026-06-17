import Foundation
import HealthKit

/// Real HealthKit-backed source. Compiles everywhere; only returns data on a
/// physical device with the HealthKit entitlement enabled and permission granted.
///
/// Not wired in by default (Phase 1 ships the mock). Enable in
/// `HealthDataSourceFactory.make()` once running on device.
actor HealthKitDataSource: HealthDataSource {
    private let store = HKHealthStore()

    nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Types we read.
    private var readTypes: Set<HKObjectType> {
        var t: Set<HKObjectType> = []
        let q: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .basalEnergyBurned, .heartRate,
            .heartRateVariabilitySDNN, .restingHeartRate, .oxygenSaturation,
            .bodyTemperature, .respiratoryRate, .vo2Max, .bodyMass, .bodyFatPercentage,
            .height, .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
            .dietaryFatTotal, .dietaryWater, .distanceWalkingRunning, .distanceCycling, .distanceSwimming
        ]
        for id in q { if let qt = HKQuantityType.quantityType(forIdentifier: id) { t.insert(qt) } }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(sleep) }
        t.insert(HKObjectType.workoutType())
        return t
    }

    // Types we write back (Apple Health stays consistent with LIVA logs).
    private var shareTypes: Set<HKSampleType> {
        var t: Set<HKSampleType> = []
        let q: [HKQuantityTypeIdentifier] = [
            .bodyMass, .bodyFatPercentage, .dietaryEnergyConsumed, .dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal, .dietaryWater, .activeEnergyBurned
        ]
        for id in q { if let qt = HKQuantityType.quantityType(forIdentifier: id) { t.insert(qt) } }
        t.insert(HKObjectType.workoutType())
        return t
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: Today aggregates

    func todaySteps() async -> Int? {
        await sumToday(.stepCount, unit: .count()).map { Int($0) }
    }

    func todayActiveCalories() async -> Int? {
        await sumToday(.activeEnergyBurned, unit: .kilocalorie()).map { Int($0) }
    }

    // MARK: Latest biometrics

    func latestBiometrics() async -> [Biometric] {
        var out: [Biometric] = []
        if let v = await latestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) {
            out.append(Biometric(recordedAt: Date(), metric: .hrv, value: v, unit: "ms", source: .healthkit))
        }
        if let v = await latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) {
            out.append(Biometric(recordedAt: Date(), metric: .rhr, value: v, unit: "bpm", source: .healthkit))
        }
        if let v = await latestQuantity(.oxygenSaturation, unit: .percent()) {
            out.append(Biometric(recordedAt: Date(), metric: .spo2, value: (v * 100).rounded(), unit: "%", source: .healthkit))
        }
        if let v = await latestQuantity(.bodyTemperature, unit: .degreeFahrenheit()) {
            out.append(Biometric(recordedAt: Date(), metric: .bodyTemp, value: v, unit: "°F", source: .healthkit))
        }
        if let hours = await lastNightSleepHours() {
            out.append(Biometric(recordedAt: Date(), metric: .sleepHours, value: hours, unit: "hrs", source: .healthkit))
        }
        return out
    }

    func series(_ metric: BiometricKind, from: Date, to: Date) async -> [Biometric] {
        guard let id = Self.quantityID(for: metric),
              let qType = HKQuantityType.quantityType(forIdentifier: id),
              let unit = Self.unit(for: metric)
        else { return [] }

        return await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            var interval = DateComponents(); interval.day = 1
            let anchor = Calendar.current.startOfDay(for: from)
            let q = HKStatisticsCollectionQuery(
                quantityType: qType, quantitySamplePredicate: predicate,
                options: .discreteAverage, anchorDate: anchor, intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, _ in
                var points: [Biometric] = []
                results?.enumerateStatistics(from: from, to: to) { stat, _ in
                    if let avg = stat.averageQuantity()?.doubleValue(for: unit) {
                        let scaled = metric == .spo2 ? avg * 100 : avg
                        points.append(Biometric(recordedAt: stat.startDate, metric: metric,
                                                 value: scaled, unit: metric.unit, source: .healthkit))
                    }
                }
                cont.resume(returning: points)
            }
            store.execute(q)
        }
    }

    // MARK: Helpers

    private static func quantityID(for metric: BiometricKind) -> HKQuantityTypeIdentifier? {
        switch metric {
        case .hrv: return .heartRateVariabilitySDNN
        case .rhr: return .restingHeartRate
        case .hr: return .heartRate
        case .spo2: return .oxygenSaturation
        case .bodyTemp: return .bodyTemperature
        case .respiratoryRate: return .respiratoryRate
        case .vo2max: return .vo2Max
        default: return nil
        }
    }

    private static func unit(for metric: BiometricKind) -> HKUnit? {
        switch metric {
        case .hrv: return HKUnit.secondUnit(with: .milli)
        case .rhr, .hr, .respiratoryRate: return HKUnit.count().unitDivided(by: .minute())
        case .spo2: return .percent()
        case .bodyTemp: return .degreeFahrenheit()
        case .vo2max: return HKUnit(from: "ml/kg*min")
        default: return nil
        }
    }

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let qType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: qType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let qType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: qType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            store.execute(q)
        }
    }

    private func lastNightSleepHours() async -> Double? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample])?.filter { sample in
                    if #available(iOS 16.0, *) {
                        return [HKCategoryValueSleepAnalysis.asleepCore,
                                .asleepDeep, .asleepREM, .asleepUnspecified]
                            .map(\.rawValue).contains(sample.value)
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                } ?? []
                let seconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: seconds > 0 ? (seconds / 3600).rounded(toPlaces: 1) : nil)
            }
            store.execute(q)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places)); return (self * p).rounded() / p
    }
}
