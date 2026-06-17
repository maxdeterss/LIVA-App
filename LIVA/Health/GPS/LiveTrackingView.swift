import SwiftUI
import MapKit

/// The live recording screen: real-time route map + big metrics + controls.
struct LiveTrackingView: View {
    @Bindable var recorder: ActivityRecorder
    var onFinish: () -> Void

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var confirmStop = false

    private var coords: [CLLocationCoordinate2D] { recorder.points.map(\.coordinate) }

    var body: some View {
        ZStack(alignment: .bottom) {
            map
            VStack(spacing: 0) {
                metricsHeader
                Spacer()
                controls
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if coords.count > 1 {
                MapPolyline(coordinates: coords)
                    .stroke(Theme.Palette.accentDeep, style: StrokeStyle(lineWidth: 6, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .topTrailing) {
            Button { camera = .userLocation(fallback: .automatic) } label: {
                Image(systemName: "location.fill").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink).frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .padding(.trailing, 16).padding(.top, 60)
        }
    }

    private var metricsHeader: some View {
        VStack(spacing: 14) {
            if recorder.autoPaused {
                Text("AUTO-PAUSED").font(.system(size: 12, weight: .bold)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.Palette.like))
            }
            HStack(spacing: 0) {
                metric(primaryDistance, "DISTANCE")
                metric(GPSMath.formatDuration(recorder.elapsedS), "TIME")
                metric(GPSMath.formatPace(secPerKm: recorder.avgPaceSecPerKm, imperial: recorder.useImperial), "AVG PACE")
            }
            HStack(spacing: 0) {
                metric("\(Int(recorder.elevationGainM)) m", "ELEV GAIN", small: true)
                metric(GPSMath.formatPace(secPerKm: recorder.currentPaceSecPerKm, imperial: recorder.useImperial), "PACE", small: true)
                metric("\(recorder.splits.count)", recorder.useImperial ? "MILES" : "KM", small: true)
            }
        }
        .padding(.top, 64).padding(.bottom, 18).padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            Theme.Palette.background.opacity(0.96)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .ignoresSafeArea(edges: .top)
        )
    }

    private func metric(_ value: String, _ label: String, small: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: small ? 22 : 34, weight: .bold))
                .monospacedDigit().foregroundStyle(Theme.Palette.ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryDistance: String {
        let miles = HealthMath.metersToMiles(recorder.displayDistanceM)
        return String(format: "%.2f", recorder.useImperial ? miles : recorder.displayDistanceM / 1000)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if recorder.state == .recording {
                circle("pause.fill", Theme.Palette.ink) { recorder.pause() }
            } else {
                circle("play.fill", Theme.Palette.accentDeep) { recorder.resume() }
            }
            Button { confirmStop = true } label: {
                Text("Finish").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(fill: Theme.Palette.like, textColor: .white))
            .confirmationDialog("Finish this activity?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Finish & Review") { onFinish() }
                Button("Keep Recording", role: .cancel) {}
            }
        }
        .padding(Theme.Spacing.screen)
        .background(Theme.Palette.background.opacity(0.96).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)))
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    private func circle(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                .frame(width: 64, height: 64).background(Circle().fill(color))
        }.buttonStyle(.plain)
    }
}
