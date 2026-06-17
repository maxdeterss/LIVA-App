import SwiftUI

/// Standard logging-sheet chrome: title, cancel, and a sticky Save button.
/// Shared across the app's logging and editing sheets.
struct LogSheet<Content: View>: View {
    let title: String
    let canSave: Bool
    var isSaving: Bool = false
    let onSave: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) { content }
                        .padding(Theme.Spacing.screen)
                        .padding(.bottom, 90)
                }
                VStack {
                    Spacer()
                    Button { onSave() } label: {
                        HStack {
                            if isSaving { ProgressView().tint(Theme.Palette.tabBarText) }
                            Text("Save")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave || isSaving)
                    .opacity(canSave ? 1 : 0.6)
                    .padding(Theme.Spacing.screen)
                    .background(Theme.Palette.background.opacity(0.95))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

/// Labeled numeric input row.
struct NumberField: View {
    let label: String
    @Binding var text: String
    var unit: String = ""
    var decimal: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            HStack {
                TextField("0", text: $text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .inputFieldStyle()
        }
    }
}

/// Shared numeric parsing helpers.
func parseInt(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespaces)) }
func parseDouble(_ s: String) -> Double? { Double(s.trimmingCharacters(in: .whitespaces)) }
