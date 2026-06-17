import Foundation
import CoreLocation

/// Abstraction over location updates so the tracker is testable and runnable in
/// the simulator. Device uses `CoreLocationProvider`; the simulator uses
/// `SimulatedLocationProvider` (replays a demo route) so the live tracker is
/// fully demonstrable without external GPS.
@MainActor
protocol LocationProvider: AnyObject {
    var onUpdate: ((CLLocation) -> Void)? { get set }
    var onAuthChange: ((CLAuthorizationStatus) -> Void)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func start(activityType: CLActivityType)
    func stop()
}

enum LocationProviderFactory {
    @MainActor static func make() -> LocationProvider {
        #if targetEnvironment(simulator)
        return SimulatedLocationProvider()
        #else
        return CoreLocationProvider()
        #endif
    }
}

// MARK: - Real CoreLocation

@MainActor
final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onUpdate: ((CLLocation) -> Void)?
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }
    func requestAlwaysAuthorization() { manager.requestAlwaysAuthorization() }

    func start(activityType: CLActivityType) {
        manager.activityType = activityType
        // NOTE: allowsBackgroundLocationUpdates must stay false unless the
        // "location" UIBackgroundMode is present in Info.plist (else it throws).
        // Enable both together when wiring background tracking on device.
        if backgroundModeEnabled {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    private var backgroundModeEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") ?? false
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locs = locations
        Task { @MainActor in locs.forEach { self.onUpdate?($0) } }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.onAuthChange?(status) }
    }
}

// MARK: - Simulated (simulator / previews / tests)

@MainActor
final class SimulatedLocationProvider: LocationProvider {
    var onUpdate: ((CLLocation) -> Void)?
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse

    private var timer: Timer?
    private var index = 0

    /// A gentle ~loop around a park, with mild elevation, for demoing.
    private let route: [(Double, Double, Double)] = {
        var pts: [(Double, Double, Double)] = []
        let baseLat = 40.7829, baseLng = -73.9654   // Central Park-ish
        for i in 0..<240 {
            let t = Double(i) / 240 * 2 * .pi
            let lat = baseLat + 0.004 * sin(t)
            let lng = baseLng + 0.006 * cos(t)
            let alt = 30 + 12 * sin(t * 2)
            pts.append((lat, lng, alt))
        }
        return pts
    }()

    func requestWhenInUseAuthorization() { onAuthChange?(.authorizedWhenInUse) }
    func requestAlwaysAuthorization() { authorizationStatus = .authorizedAlways; onAuthChange?(.authorizedAlways) }

    func start(activityType: CLActivityType) {
        index = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func tick() {
        guard index < route.count else { stop(); return }
        let p = route[index]; index += 1
        let loc = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: p.0, longitude: p.1),
            altitude: p.2, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 3.0, timestamp: Date()
        )
        onUpdate?(loc)
    }
}
