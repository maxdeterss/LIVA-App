import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        LivaCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel("Account")
                                row("person", "Signed in as", value: session.profile?.handle ?? "—")
                                Divider().overlay(Theme.Palette.divider)
                                row("target", "Goal", value: session.profile?.goal?.title ?? "—")
                            }
                        }

                        LivaCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel("About")
                                row("sparkles", "Version", value: "1.0 (MVP)")
                                Divider().overlay(Theme.Palette.divider)
                                row("doc.text", "Terms & Privacy", value: "")
                            }
                        }

                        Button("Sign Out") {
                            Task { await session.signOut(); dismiss() }
                        }
                        .buttonStyle(PrimaryButtonStyle(fill: Theme.Palette.like, textColor: .white))
                    }
                    .padding(Theme.Spacing.screen)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
        }
    }

    private func row(_ icon: String, _ title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.Palette.accent).frame(width: 22)
            Text(title).font(.system(size: 15)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text(value).font(.system(size: 15)).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}
