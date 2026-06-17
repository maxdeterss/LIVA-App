import SwiftUI
import MapKit
import Charts

struct ActivitySummaryView: View {
    let draft: ActivitySummaryDraft
    var onDone: () -> Void

    @Environment(HealthEnvironment.self) private var env
    @State private var title = ""
    @State private var notes = ""
    @State private var privacy: Privacy = .followers
    @State private var shareToFeed = true
    @State private var saving = false
    @State private var newRecords: [PersonalRecordItem] = []
    @State private var showPRs = false

    private var coords: [CLLocationCoordinate2D] { draft.points.map(\.coordinate) }
    private var imperial: Bool { true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                routeMap
                titleEditor
                statGrid
                if !draft.splits.isEmpty { splitsCard }
                if draft.points.count > 2 { elevationCard }
                privacyCard
                saveButton
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 12).padding(.bottom, 40)
        }
        .background(LivaBackground())
        .onAppear {
            title = autoTitle
        }
        .overlay { if showPRs { prCelebration } }
    }

    // MARK: Map

    @ViewBuilder private var routeMap: some View {
        if coords.count > 1 {
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: coords)
                    .stroke(Theme.Palette.accentDeep, style: StrokeStyle(lineWidth: 5, lineJoin: .round))
                if let s = coords.first { Annotation("Start", coordinate: s) { pin(Theme.Palette.accent) } }
                if let e = coords.last { Annotation("Finish", coordinate: e) { pin(Theme.Palette.ink) } }
            }
            .mapStyle(.standard)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Palette.surface)
                .frame(height: 120)
                .overlay(Label("Indoor activity", systemImage: "house").foregroundStyle(Theme.Palette.inkSecondary))
        }
    }

    private func pin(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3))
    }

    private var region: MKCoordinateRegion {
        guard let b = GPSMath.bounds(draft.points) else {
            return MKCoordinateRegion(center: .init(latitude: 0, longitude: 0),
                                      span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        let center = CLLocationCoordinate2D(latitude: (b["minLat"]! + b["maxLat"]!) / 2,
                                            longitude: (b["minLng"]! + b["maxLng"]!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((b["maxLat"]! - b["minLat"]!) * 1.4, 0.005),
                                    longitudeDelta: max((b["maxLng"]! - b["minLng"]!) * 1.4, 0.005))
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: Title

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Activity title", text: $title)
                .font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            HStack(spacing: 6) {
                Image(systemName: draft.sport.symbol)
                Text(draft.sport.title.uppercased()).tracking(1)
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    // MARK: Stats

    private var statGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LivaCard {
            LazyVGrid(columns: cols, spacing: 18) {
                stat(distanceStr, imperial ? "MILES" : "KM")
                stat(GPSMath.formatDuration(draft.movingTimeS), "MOVING")
                stat(GPSMath.formatPace(secPerKm: draft.avgPaceSecPerKm, imperial: imperial), "AVG PACE")
                stat("\(Int(draft.elevationGainM))", "ELEV ↑ (M)")
                stat("\(draft.calories)", "CALORIES")
                stat(GPSMath.formatDuration(draft.elapsedTimeS), "ELAPSED")
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
                .foregroundStyle(Theme.Palette.ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }.frame(maxWidth: .infinity)
    }

    private var distanceStr: String {
        String(format: "%.2f", imperial ? HealthMath.metersToMiles(draft.distanceM) : draft.distanceM / 1000)
    }

    // MARK: Splits

    private var splitsCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(imperial ? "Mile splits" : "Km splits")
                ForEach(draft.splits) { s in
                    HStack {
                        Text("\(s.index)").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink).frame(width: 28, alignment: .leading)
                        let frac = min(s.paceSecPerKm / (slowestPace == 0 ? 1 : slowestPace), 1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.Palette.track)
                                Capsule().fill(s.id == fastestSplit?.id ? Theme.Palette.accentDeep : Theme.Palette.accent)
                                    .frame(width: geo.size.width * frac)
                            }
                        }.frame(height: 8)
                        Text(GPSMath.formatPace(secPerKm: s.paceSecPerKm, imperial: imperial))
                            .font(.system(size: 13, weight: .medium)).monospacedDigit()
                            .foregroundStyle(Theme.Palette.ink).frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var slowestPace: Double { draft.splits.map(\.paceSecPerKm).max() ?? 0 }
    private var fastestSplit: Split? { draft.splits.min(by: { $0.paceSecPerKm < $1.paceSecPerKm }) }

    // MARK: Elevation chart

    private var elevationCard: some View {
        let series = elevationSeries
        return LivaCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Elevation")
                Chart(series, id: \.0) { item in
                    AreaMark(x: .value("Distance", item.0), y: .value("Altitude", item.1))
                        .foregroundStyle(LinearGradient(colors: [Theme.Palette.accent.opacity(0.3), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Distance", item.0), y: .value("Altitude", item.1))
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
                .frame(height: 140)
            }
        }
    }

    private var elevationSeries: [(Double, Double)] {
        var cumulative = 0.0
        var out: [(Double, Double)] = []
        for (i, p) in draft.points.enumerated() {
            if i > 0 { cumulative += GPSMath.distance(draft.points[i-1], p) }
            out.append((HealthMath.metersToMiles(cumulative), p.altitude))
        }
        return out
    }

    // MARK: Privacy + share

    private var privacyCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Privacy")
                    Picker("Privacy", selection: $privacy) {
                        ForEach(Privacy.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Toggle("Share to my Loops feed", isOn: $shareToFeed).tint(Theme.Palette.accent)
                TextField("How did it feel?", text: $notes, axis: .vertical).lineLimit(2...4).inputFieldStyle()
            }
        }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            HStack { if saving { ProgressView().tint(Theme.Palette.tabBarText) }; Text("Save Activity") }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(saving)
    }

    private func save() async {
        saving = true
        let service = ActivitySaveService(writer: RemoteWriter(queue: env.queue))
        do {
            let result = try await service.save(draft: draft, title: title.isEmpty ? autoTitle : title,
                                                notes: notes.isEmpty ? nil : notes, privacy: privacy, gearID: nil)
            if shareToFeed { try? await service.shareToFeed(draft: draft, title: title) }
            saving = false
            if result.newRecords.isEmpty { onDone() }
            else { newRecords = result.newRecords; withAnimation { showPRs = true } }
        } catch {
            saving = false
            onDone() // best-effort; offline writes are queued by the service
        }
    }

    // MARK: PR celebration

    private var prCelebration: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "trophy.fill").font(.system(size: 44)).foregroundStyle(Theme.Palette.accent)
                Text("New Personal Record!").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Palette.ink)
                VStack(spacing: 8) {
                    ForEach(newRecords) { r in
                        HStack {
                            Text(r.title).font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text(r.recordType.hasPrefix("fastest")
                                 ? GPSMath.formatDuration(r.value)
                                 : String(format: "%.0f m", r.value))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(Theme.Palette.ink)
                    }
                }
                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 220)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sheet).fill(Theme.Palette.background))
            .padding(40)
        }
    }

    private var autoTitle: String {
        let h = Calendar.current.component(.hour, from: draft.startedAt)
        let part = h < 12 ? "Morning" : h < 17 ? "Afternoon" : h < 21 ? "Evening" : "Night"
        return "\(part) \(draft.sport.title)"
    }
}
