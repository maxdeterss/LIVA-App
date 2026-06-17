import SwiftUI
import CoreLocation

/// Top-level container for the record→track→summarize flow, presented full-screen.
struct ActivityFlowView: View {
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = ActivityRecorder()
    @State private var draft: ActivitySummaryDraft?
    @State private var recovery: ActivitySnapshot?

    var body: some View {
        Group {
            if let draft {
                ActivitySummaryView(draft: draft) { dismiss() }
            } else {
                switch recorder.state {
                case .idle:
                    RecordSetupView(recorder: recorder, onStart: { recorder.start() }, onClose: { dismiss() })
                case .recording, .paused:
                    LiveTrackingView(recorder: recorder, onFinish: { draft = recorder.finish() })
                case .finished:
                    Color.clear
                }
            }
        }
        .onAppear {
            if recorder.state == .idle, let snap = ActivityRecorder.recoverable(), snap.points.count > 5 {
                recovery = snap
            }
        }
        .alert("Resume unfinished activity?", isPresented: .constant(recovery != nil)) {
            Button("Resume") { if let s = recovery { recorder.restore(from: s); recovery = nil } }
            Button("Discard", role: .destructive) { recorder.discardRecoverable(); recovery = nil }
        } message: {
            Text("LIVA found an activity that wasn't saved. You can pick up where you left off.")
        }
    }
}

// MARK: - Setup

struct RecordSetupView: View {
    @Bindable var recorder: ActivityRecorder
    var onStart: () -> Void
    var onClose: () -> Void

    private let sports: [WorkoutKind] = [.cardioRun, .cardioRide, .cardioWalk, .cardioHike, .cardioSwim, .other]

    var body: some View {
        ZStack {
            LivaBackground()
            VStack(spacing: Theme.Spacing.xl) {
                HStack {
                    Button { onClose() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)) }
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Text("RECORD").font(.system(size: 13, weight: .semibold)).tracking(2)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Image(systemName: "xmark").opacity(0)
                }

                LivaCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel("Activity")
                        FlowLayout(spacing: 8) {
                            ForEach(sports) { s in
                                SelectablePill(title: s.title, systemName: s.symbol, isSelected: recorder.sport == s) {
                                    recorder.sport = s
                                }
                            }
                        }
                        Toggle("Indoor / no GPS", isOn: $recorder.isIndoor).tint(Theme.Palette.accent)
                        Toggle("Audio cues", isOn: $recorder.voiceEnabled).tint(Theme.Palette.accent)
                    }
                }

                if !recorder.isIndoor { permissionRow }

                Spacer()

                Button {
                    if recorder.isIndoor || recorder.hasLocationPermission { onStart() }
                    else { recorder.requestPermission() }
                } label: {
                    Text(startLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.Palette.like, textColor: .white))
            }
            .padding(Theme.Spacing.screen)
        }
    }

    private var startLabel: String {
        if recorder.isIndoor { return "Start" }
        return recorder.hasLocationPermission ? "Start" : "Allow Location & Start"
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: recorder.hasLocationPermission ? "location.fill" : "location.slash")
                .foregroundStyle(recorder.hasLocationPermission ? Theme.Palette.accent : Theme.Palette.inkSecondary)
            Text(recorder.hasLocationPermission
                 ? "GPS ready. Tracking continues with the screen off."
                 : "LIVA needs location to map your route. Tracking continues in your pocket.")
                .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.surface))
    }
}
