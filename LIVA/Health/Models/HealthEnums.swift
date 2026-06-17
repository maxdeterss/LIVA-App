import SwiftUI

// MARK: - Workout kind (maps Postgres `workout_type`)

enum WorkoutKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case lift, cardioRun = "cardio_run", cardioRide = "cardio_ride",
         cardioWalk = "cardio_walk", cardioHike = "cardio_hike",
         cardioSwim = "cardio_swim", yoga, hiit, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lift: return "Lift"
        case .cardioRun: return "Run"
        case .cardioRide: return "Ride"
        case .cardioWalk: return "Walk"
        case .cardioHike: return "Hike"
        case .cardioSwim: return "Swim"
        case .yoga: return "Yoga"
        case .hiit: return "HIIT"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .lift: return "dumbbell.fill"
        case .cardioRun: return "figure.run"
        case .cardioRide: return "figure.outdoor.cycle"
        case .cardioWalk: return "figure.walk"
        case .cardioHike: return "figure.hiking"
        case .cardioSwim: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .hiit: return "bolt.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// Whether this kind logs per-exercise strength sets.
    var isStrength: Bool { self == .lift || self == .hiit }

    /// GPS-based outdoor cardio (Phase 2 hook).
    var isGPS: Bool {
        [.cardioRun, .cardioRide, .cardioWalk, .cardioHike, .cardioSwim].contains(self)
    }
}

// MARK: - Source of a record (device/manual)

enum MetricSource: String, Codable, CaseIterable, Hashable {
    case manual, healthkit, watch, whoop, oura, garmin

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .healthkit: return "Apple Health"
        case .watch: return "Apple Watch"
        case .whoop: return "WHOOP"
        case .oura: return "Oura"
        case .garmin: return "Garmin"
        }
    }
}

// MARK: - Privacy

enum Privacy: String, Codable, CaseIterable, Identifiable, Hashable {
    case everyone, followers, onlyMe = "only_me"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .everyone: return "Everyone"
        case .followers: return "Followers"
        case .onlyMe: return "Only Me"
        }
    }
    var symbol: String {
        switch self {
        case .everyone: return "globe"
        case .followers: return "person.2.fill"
        case .onlyMe: return "lock.fill"
        }
    }
}

// MARK: - Biometric kind

enum BiometricKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case hrv, rhr, hr, spo2, bodyTemp = "body_temp",
         sleepHours = "sleep_hours", respiratoryRate = "respiratory_rate",
         vo2max, bpSystolic = "bp_systolic", bpDiastolic = "bp_diastolic",
         bloodGlucose = "blood_glucose"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hrv: return "HRV"
        case .rhr: return "Resting HR"
        case .hr: return "Heart Rate"
        case .spo2: return "SpO₂"
        case .bodyTemp: return "Body Temp"
        case .sleepHours: return "Sleep"
        case .respiratoryRate: return "Respiratory Rate"
        case .vo2max: return "VO₂ Max"
        case .bpSystolic: return "BP (Systolic)"
        case .bpDiastolic: return "BP (Diastolic)"
        case .bloodGlucose: return "Blood Glucose"
        }
    }

    /// Short label for the dashboard biometrics row.
    var shortLabel: String {
        switch self {
        case .hrv: return "HRV"
        case .rhr: return "RHR"
        case .sleepHours: return "HRS\nSLEEP"
        case .spo2: return "SPO2"
        case .bodyTemp: return "TEMP"
        default: return title.uppercased()
        }
    }

    var symbol: String {
        switch self {
        case .hrv: return "heart.text.square"
        case .rhr, .hr: return "heart"
        case .spo2: return "drop"
        case .bodyTemp: return "thermometer.medium"
        case .sleepHours: return "moon.zzz"
        case .respiratoryRate: return "lungs"
        case .vo2max: return "figure.run.circle"
        case .bpSystolic, .bpDiastolic: return "waveform.path.ecg"
        case .bloodGlucose: return "drop.triangle"
        }
    }

    var unit: String {
        switch self {
        case .hrv: return "ms"
        case .rhr, .hr: return "bpm"
        case .spo2: return "%"
        case .bodyTemp: return "°F"
        case .sleepHours: return "hrs"
        case .respiratoryRate: return "br/min"
        case .vo2max: return "ml/kg/min"
        case .bpSystolic, .bpDiastolic: return "mmHg"
        case .bloodGlucose: return "mg/dL"
        }
    }

    /// The five shown on the dashboard biometrics row, in order.
    static let dashboard: [BiometricKind] = [.hrv, .rhr, .sleepHours, .spo2, .bodyTemp]
}

// MARK: - Units & sex

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
}

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male, female, other, unspecified
    var id: String { rawValue }
}
