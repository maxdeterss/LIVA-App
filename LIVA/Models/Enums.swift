import SwiftUI

// MARK: - Goal

/// The fitness goal a user selects during onboarding.
enum Goal: String, Codable, CaseIterable, Identifiable {
    case loseFat = "lose_fat"
    case buildMuscle = "build_muscle"
    case stayConsistent = "stay_consistent"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseFat: return "Lose Fat"
        case .buildMuscle: return "Build Muscle"
        case .stayConsistent: return "Stay Consistent"
        }
    }

    var subtitle: String {
        switch self {
        case .loseFat: return "Lean out and shed body fat"
        case .buildMuscle: return "Add size and get stronger"
        case .stayConsistent: return "Show up and keep the streak"
        }
    }

    var symbol: String {
        switch self {
        case .loseFat: return "flame"
        case .buildMuscle: return "dumbbell"
        case .stayConsistent: return "calendar"
        }
    }
}

// MARK: - Content interests

/// Content preference tags chosen at onboarding and used to seed the feed.
enum ContentInterest: String, Codable, CaseIterable, Identifiable {
    case weightlifting
    case health
    case mindset
    case wellness
    case running
    case pilates
    case crossfit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weightlifting: return "Weight Lifting"
        case .crossfit: return "Cross-Fit"
        default: return rawValue.capitalized
        }
    }

    var symbol: String {
        switch self {
        case .weightlifting: return "dumbbell.fill"
        case .health: return "heart.fill"
        case .mindset: return "brain.head.profile"
        case .wellness: return "leaf.fill"
        case .running: return "figure.run"
        case .pilates: return "figure.pilates"
        case .crossfit: return "figure.cross.training"
        }
    }
}

// MARK: - Media

enum MediaType: String, Codable {
    case image
    case video
}

// MARK: - Workout

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case strength, cardio, run, cycle, swim, hiit, yoga, pilates, crossfit, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hiit: return "HIIT"
        case .crossfit: return "Cross-Fit"
        default: return rawValue.capitalized
        }
    }

    var symbol: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .run: return "figure.run"
        case .cycle: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .hiit: return "bolt.fill"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .crossfit: return "figure.cross.training"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// Strength workouts capture per-exercise sets/reps.
    var tracksExercises: Bool { self == .strength || self == .crossfit || self == .hiit }
}

// MARK: - Nutrition

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        }
    }
}

// MARK: - Creator links

enum LinkKind: String, Codable, CaseIterable, Identifiable {
    case social, affiliate, website
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .social: return "person.2.fill"
        case .affiliate: return "tag.fill"
        case .website: return "link"
        }
    }
}
