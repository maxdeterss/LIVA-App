import SwiftUI
import UIKit

struct LogWorkoutView: View {
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: WorkoutKind = .lift
    @State private var duration = ""
    @State private var calories = ""
    @State private var avgHR = ""
    @State private var maxHR = ""
    @State private var notes = ""
    @State private var sets: [DraftSet] = [DraftSet()]
    @State private var privacy: Privacy = .followers
    @State private var saving = false

    struct DraftSet: Identifiable {
        let id = UUID()
        var name = ""
        var reps = ""
        var weight = ""
        var rpe = ""
    }

    var body: some View {
        LogSheet(title: "Log Workout", canSave: true, isSaving: saving) {
            save()
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("TITLE").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField(type.title, text: $title).inputFieldStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(WorkoutKind.allCases) { k in
                        SelectablePill(title: k.title, systemName: k.symbol, isSelected: type == k) {
                            withAnimation { type = k }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                NumberField(label: "Duration", text: $duration, unit: "min")
                NumberField(label: "Calories", text: $calories, unit: "cal")
            }
            HStack(spacing: 12) {
                NumberField(label: "Avg HR", text: $avgHR, unit: "bpm")
                NumberField(label: "Max HR", text: $maxHR, unit: "bpm")
            }

            if type.isStrength { exercisesSection; RestTimerView() }

            VStack(alignment: .leading, spacing: 8) {
                Text("PRIVACY").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Picker("Privacy", selection: $privacy) {
                    ForEach(Privacy.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("How did it go?", text: $notes, axis: .vertical).lineLimit(2...4).inputFieldStyle()
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISES").font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            ForEach($sets) { $set in
                VStack(spacing: 8) {
                    TextField("Exercise name", text: $set.name).inputFieldStyle()
                    HStack(spacing: 8) {
                        compact("Reps", text: $set.reps)
                        compact("Kg", text: $set.weight, decimal: true)
                        compact("RPE", text: $set.rpe, decimal: true)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.surfaceRaised))
            }
            Button { sets.append(DraftSet()) } label: {
                Label("Add exercise", systemImage: "plus").font(.system(size: 14, weight: .medium))
            }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private func compact(_ placeholder: String, text: Binding<String>, decimal: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center).font(.system(size: 15))
            .padding(.vertical, 12).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
    }

    private func save() {
        saving = true
        let exercises: [StrengthSet]? = type.isStrength
            ? sets.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                .enumerated().map { idx, s in
                    StrengthSet(workoutID: nil, exerciseID: nil, exerciseName: s.name, setIndex: idx,
                                reps: parseInt(s.reps), weightKg: parseDouble(s.weight),
                                rpe: parseDouble(s.rpe), restS: nil)
                }
            : nil
        let durationS = parseInt(duration).map { $0 * 60 }
        let workout = Workout(
            userID: nil, type: type, source: .manual,
            title: title.isEmpty ? nil : title, startedAt: Date(), endedAt: Date(),
            durationS: durationS, totalCalories: parseInt(calories),
            avgHR: parseInt(avgHR), maxHR: parseInt(maxHR),
            notes: notes.isEmpty ? nil : notes, privacy: privacy, sets: exercises
        )
        Task { try? await env.workouts.log(workout); saving = false; dismiss() }
    }
}

// MARK: - Rest timer (haptic on completion)

struct RestTimerView: View {
    @State private var remaining = 0
    @State private var running = false
    private let presets = [60, 90, 120, 180]
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REST TIMER").font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            HStack(spacing: 12) {
                Text(timeString).font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(Theme.Palette.ink)
                Spacer()
                if running {
                    Button { stop() } label: { Image(systemName: "stop.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.Palette.like).font(.system(size: 22))
                }
            }
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { sec in
                    Button { start(sec) } label: {
                        Text("\(sec)s").font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(Theme.Palette.chip)).foregroundStyle(Theme.Palette.ink)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.surfaceRaised))
        .onReceive(ticker) { _ in tick() }
    }

    private var timeString: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }

    private func start(_ seconds: Int) {
        remaining = seconds; running = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    private func stop() { running = false; remaining = 0 }
    private func tick() {
        guard running else { return }
        if remaining > 1 {
            remaining -= 1
            if remaining <= 3 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        } else {
            remaining = 0; running = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
