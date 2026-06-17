import SwiftUI
import PhotosUI

/// Three-step onboarding: identity → goal → content preferences.
struct OnboardingView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = OnboardingViewModel()

    var body: some View {
        ZStack {
            LivaBackground()
            VStack(spacing: 0) {
                progressBar
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        switch model.step {
                        case 0: identityStep
                        case 1: goalStep
                        default: interestsStep
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                controls
            }
        }
        .onAppear { model.prefill(from: session.profile) }
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<model.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= model.step ? Theme.Palette.ink : Theme.Palette.track)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
    }

    // MARK: Step 1 — identity

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            stepTitle("Welcome to LIVA", "Let's set up your profile.")

            HStack {
                Spacer()
                PhotosPicker(selection: $model.photoItem, matching: .images) {
                    ZStack {
                        if let img = model.avatarImage {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 104, height: 104).clipShape(Circle())
                        } else {
                            Circle().fill(Theme.Palette.chip).frame(width: 104, height: 104)
                                .overlay(Image(systemName: "camera").font(.system(size: 26))
                                    .foregroundStyle(Theme.Palette.inkSecondary))
                        }
                        Circle().stroke(Theme.Palette.divider, lineWidth: 1).frame(width: 104, height: 104)
                    }
                }
                Spacer()
            }

            VStack(spacing: 14) {
                labeledField("USERNAME") {
                    HStack(spacing: 4) {
                        Text("@").foregroundStyle(Theme.Palette.inkSecondary)
                        TextField("username", text: $model.username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .inputFieldStyle()
                }
                labeledField("DISPLAY NAME") {
                    TextField("Your name", text: $model.displayName).inputFieldStyle()
                }
                labeledField("BIO (OPTIONAL)") {
                    TextField("Building discipline. Chasing growth.", text: $model.bio, axis: .vertical)
                        .lineLimit(2...4).inputFieldStyle()
                }
            }
        }
    }

    // MARK: Step 2 — goal

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            stepTitle("What's your goal?", "We'll tailor your experience around it.")
            VStack(spacing: 12) {
                ForEach(Goal.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: Goal) -> some View {
        let selected = model.goal == goal
        return Button { withAnimation { model.goal = goal } } label: {
            HStack(spacing: 14) {
                IconCircle(systemName: goal.symbol, size: 46,
                           fill: selected ? Theme.Palette.ink : Theme.Palette.chip,
                           tint: selected ? Theme.Palette.tabBarText : Theme.Palette.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title).font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(goal.subtitle).font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.Palette.ink : Theme.Palette.track)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(selected ? Theme.Palette.ink : Theme.Palette.divider, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 3 — interests

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            stepTitle("What do you want to see?", "Pick a few — you can change these later.")
            FlowLayout(spacing: 10) {
                ForEach(ContentInterest.allCases) { interest in
                    SelectablePill(
                        title: interest.title,
                        systemName: interest.symbol,
                        isSelected: model.interests.contains(interest)
                    ) { model.toggle(interest) }
                }
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if let error = model.error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.Palette.like)
            }
            HStack(spacing: 12) {
                if model.step > 0 {
                    Button("Back") { model.back() }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 110)
                }
                Button {
                    if model.step < model.totalSteps - 1 { model.advance() }
                    else { Task { await model.finish(session: session) } }
                } label: {
                    HStack {
                        if model.isWorking { ProgressView().tint(Theme.Palette.tabBarText) }
                        Text(model.step < model.totalSteps - 1 ? "Continue" : "Enter LIVA")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.canAdvance || model.isWorking)
                .opacity(model.canAdvance ? 1 : 0.6)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Theme.Palette.background)
    }

    // MARK: Helpers

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            content()
        }
    }
}
