import Foundation

/// Abstraction over the device health store so the app is testable and runs in
/// the simulator (where HealthKit is unavailable). Real device uses
/// `HealthKitDataSource`; everywhere else uses `MockHealthDataSource`.
protocol HealthDataSource: Sendable {
    /// True when a real health store is present (false in the simulator).
    var isAvailable: Bool { get }

    /// Prime + request read/write authorization. No-op for the mock.
    func requestAuthorization() async throws

    func todaySteps() async -> Int?
    func todayActiveCalories() async -> Int?

    /// Latest reading for each dashboard biometric.
    func latestBiometrics() async -> [Biometric]

    /// A time series for one metric (for the detail charts).
    func series(_ metric: BiometricKind, from: Date, to: Date) async -> [Biometric]
}

/// Selects the appropriate data source for the current environment.
enum HealthDataSourceFactory {
    /// Phase 1 ships the mock so the simulator is fully functional. Flip to
    /// `HealthKitDataSource()` once the HealthKit entitlement is enabled and
    /// you're running on a physical device (see CHANGELOG / MIGRATIONS).
    static func make() -> HealthDataSource {
        #if targetEnvironment(simulator)
        return MockHealthDataSource()
        #else
        return MockHealthDataSource() // → HealthKitDataSource() when entitlement is enabled
        #endif
    }
}

// MARK: - Mock

/// Deterministic, plausible health data for development and previews.
/// Values mirror the design mockup so the dashboard looks "live".
struct MockHealthDataSource: HealthDataSource {
    var isAvailable: Bool { false }
    func requestAuthorization() async throws {}

    func todaySteps() async -> Int? { 12_450 }
    func todayActiveCalories() async -> Int? { 620 }

    func latestBiometrics() async -> [Biometric] {
        let now = Date()
        return [
            Biometric(recordedAt: now, metric: .hrv, value: 56, unit: "ms", source: .watch),
            Biometric(recordedAt: now, metric: .rhr, value: 54, unit: "bpm", source: .watch),
            Biometric(recordedAt: now, metric: .sleepHours, value: 7.5, unit: "hrs", source: .watch),
            Biometric(recordedAt: now, metric: .spo2, value: 98, unit: "%", source: .watch),
            Biometric(recordedAt: now, metric: .bodyTemp, value: 98.6, unit: "°F", source: .watch),
        ]
    }

    func series(_ metric: BiometricKind, from: Date, to: Date) async -> [Biometric] {
        let cal = Calendar.current
        let days = max(cal.dateComponents([.day], from: from, to: to).day ?? 7, 1)
        let base: Double
        let spread: Double
        switch metric {
        case .hrv: base = 56; spread = 14
        case .rhr: base = 54; spread = 6
        case .sleepHours: base = 7.4; spread = 1.4
        case .spo2: base = 98; spread = 1.5
        case .bodyTemp: base = 98.6; spread = 0.6
        default: base = 60; spread = 10
        }
        return (0...days).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: to) else { return nil }
            // Smooth pseudo-variation without randomness (stable previews).
            let wobble = sin(Double(offset) * 0.7) * spread
            let value = (base + wobble).rounded(toPlaces: metric == .sleepHours || metric == .bodyTemp ? 1 : 0)
            return Biometric(recordedAt: date, metric: metric, value: value, unit: metric.unit, source: .watch)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
