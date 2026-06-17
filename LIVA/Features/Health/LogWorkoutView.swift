import SwiftUI

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: WorkoutType = .strength
    @State private var duration = ""
    @State private var calories = ""
    @State private var distance = ""
    @State private var steps = ""
    @State private var exercises: [DraftExercise] = [DraftExercise()]
    @State private var saving = false

    struct DraftExercise: Identifiable {
        let id = UUID()
        var name = ""
        var sets = ""
        var reps = ""
        var weight = ""
    }

    var body: some View {
        LogSheet(title: "Log Workout",
                 canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                 isSaving: saving) {
            save()
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("TITLE").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("Legs / Core", text: $title).inputFieldStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(WorkoutType.allCases) { t in
                        SelectablePill(title: t.title, systemName: t.symbol, isSelected: type == t) {
                            withAnimation { type = t }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                NumberField(label: "Duration", text: $duration, unit: "min")
                NumberField(label: "Calories", text: $calories, unit: "cal")
            }

            if type == .run || type == .cardio || type == .cycle || type == .swim {
                HStack(spacing: 12) {
                    NumberField(label: "Distance", text: $distance, unit: "mi", decimal: true)
                    NumberField(label: "Steps", text: $steps)
                }
            }

            if type.tracksExercises {
                exercisesSection
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISES").font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            ForEach($exercises) { $ex in
                VStack(spacing: 8) {
                    TextField("Exercise name", text: $ex.name).inputFieldStyle()
                    HStack(spacing: 8) {
                        compactField("Sets", text: $ex.sets)
                        compactField("Reps", text: $ex.reps)
                        compactField("Weight", text: $ex.weight, decimal: true)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Palette.surfaceRaised))
            }
            Button {
                exercises.append(DraftExercise())
            } label: {
                Label("Add exercise", systemImage: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func compactField(_ placeholder: String, text: Binding<String>, decimal: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 15))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
    }

    private func save() {
        saving = true
        let exList: [WorkoutExercise]? = type.tracksExercises
            ? exercises.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                .enumerated().map { idx, e in
                    WorkoutExercise(id: nil, workoutLogID: nil, name: e.name,
                                    sets: Int(e.sets), reps: Int(e.reps),
                                    weightKg: Double(e.weight), position: idx)
                }
            : nil

        let workout = WorkoutLog(
            id: nil, profileID: nil, title: title, type: type,
            durationMin: Int(duration), calories: Int(calories),
            distanceMiles: Double(distance), steps: Int(steps),
            notes: nil, loggedAt: Date(), exercises: exList
        )
        Task {
            try? await TrackingService.logWorkout(workout)
            saving = false; dismiss()
        }
    }
}
