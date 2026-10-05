//  The trail (stories 040–042): the opt-in background recording, the permission it needs, and the one precise fix
//  each foreground. Lives as long as the app, because iOS may launch the app in the background just to deliver
//  points. Recording is what Context Grabber does — standard updates at ~100 m accuracy, no distance filter,
//  never auto-paused — plus significant-change monitoring, so a terminated app is woken and the trail resumes
//  (docs/superpowers/specs/2026-10-04-native-places-design.md, "Rationale").

import ContextCore
import CoreLocation
import SwiftUI

@MainActor
final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
  /// What iOS has granted, as the screen shows it.
  @Published private(set) var authorization: CLAuthorizationStatus
  /// The switch: on only while Always is granted and recording runs.
  @Published private(set) var trackingOn = false
  /// A line under the switch when tracking could not be turned on, or was turned off by iOS.
  @Published private(set) var trackingNote = ""
  /// The latest precise fix: You on the map and Use current.
  @Published private(set) var you: CLLocation?
  /// Points written this launch, for the screen's count to move.
  @Published private(set) var pointsThisLaunch = 0

  private let log: SessionLog
  private let store: LocationStore?
  private let recorder = CLLocationManager()
  private let fixer = CLLocationManager()
  /// Set while the switch waits for the permission prompts to be answered.
  private var wantsTracking = false
  private var askedAlways = false
  private var fixWaiters: [(CLLocation?) -> Void] = []
  private var fixStarted: Date?
  // The sampled point log: the first batch after recording starts, then one line per quarter hour.
  private var pointsSinceLog = 0
  private var lastPointLog: Date?
  private static let pointLogInterval: TimeInterval = 15 * 60
  private var lastErrorCode: Int?

  init(log: SessionLog, store: LocationStore?) {
    self.log = log
    self.store = store
    authorization = recorder.authorizationStatus
    super.init()
    recorder.delegate = self
    recorder.desiredAccuracy = kCLLocationAccuracyHundredMeters
    recorder.distanceFilter = kCLDistanceFilterNone
    recorder.activityType = .other
    recorder.pausesLocationUpdatesAutomatically = false
    fixer.delegate = self
    fixer.desiredAccuracy = kCLLocationAccuracyBest
    resumeIfEnabled()
  }

  static func name(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "not_determined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "when_in_use"
    @unknown default: return "unknown"
    }
  }

  /// What the screen says about the permission.
  var permissionText: String {
    switch authorization {
    case .notDetermined: return "Not asked yet"
    case .restricted: return "Restricted"
    case .denied: return "Denied"
    case .authorizedAlways: return "Always"
    case .authorizedWhenInUse: return "While Using"
    @unknown default: return "Unknown"
    }
  }

  // MARK: - the switch

  /// At launch (also a background launch for a significant change): recording resumes if the switch was left on.
  private func resumeIfEnabled() {
    guard (try? store?.trackingEnabled()) == true else { return }
    if authorization == .authorizedAlways {
      start(reason: "launch")
    } else {
      // Always was taken away in Settings while the app was closed: the switch goes off, and says why.
      persist(false)
      trackingNote = "Background tracking was turned off: iOS now allows location \(permissionText.lowercased())."
      log.event("tracking", ["on": false, "reason": "permission_lost", "permission": Self.name(authorization)])
    }
  }

  func setTracking(_ on: Bool, from source: String) {
    log.event("ui", ["action": "tracking_switch", "on": on, "from": source])
    trackingNote = ""
    if !on {
      wantsTracking = false
      stop(reason: source)
      return
    }
    switch authorization {
    case .authorizedAlways:
      start(reason: source)
    case .notDetermined:
      wantsTracking = true
      log.event("location_permission", ["action": "request", "level": "when_in_use"])
      recorder.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      wantsTracking = true
      askForAlways()
    default:
      refuse()
    }
  }

  private func askForAlways() {
    askedAlways = true
    log.event("location_permission", ["action": "request", "level": "always"])
    recorder.requestAlwaysAuthorization()
  }

  /// The prompt was answered without Always (iOS may not call back when the answer keeps While Using, so the
  /// app's return to the front settles it too).
  private func refuse() {
    wantsTracking = false
    persist(false)
    trackingOn = false
    trackingNote =
      authorization == .authorizedWhenInUse
      ? "Background tracking needs location access Always; iOS allows While Using. Change it in Settings → Grabber Native → Location."
      : "Background tracking needs location access Always; iOS allows \(permissionText.lowercased()). Change it in Settings → Grabber Native → Location."
    log.event("tracking", ["on": false, "reason": "refused", "permission": Self.name(authorization)])
  }

  private func start(reason: String) {
    wantsTracking = false
    recorder.allowsBackgroundLocationUpdates = true
    recorder.showsBackgroundLocationIndicator = true
    recorder.startUpdatingLocation()
    recorder.startMonitoringSignificantLocationChanges()
    persist(true)
    trackingOn = true
    pointsSinceLog = 0
    lastPointLog = nil
    log.event("tracking", ["on": true, "reason": reason, "permission": Self.name(authorization)])
  }

  private func stop(reason: String) {
    recorder.stopUpdatingLocation()
    recorder.stopMonitoringSignificantLocationChanges()
    recorder.allowsBackgroundLocationUpdates = false
    persist(false)
    let was = trackingOn
    trackingOn = false
    if pointsSinceLog > 0 { logPoints(force: true) }
    log.event("tracking", ["on": false, "reason": reason, "was_on": was])
  }

  private func persist(_ on: Bool) {
    do {
      try store?.setTrackingEnabled(on)
    } catch {
      log.event("error", ["where": "tracking_setting", "message": "\(error)"])
    }
  }

  /// The app came back to the front: a pending Always prompt is settled, and the precise fix is asked for.
  func foreground() {
    if wantsTracking && askedAlways && authorization != .authorizedAlways && authorization != .notDetermined {
      refuse()
    }
    requestFix(reason: "foreground")
  }

  // MARK: - the precise fix (story 042)

  /// One precise fix; `done` gets it (nil when there is no permission or it failed). Asks While Using first if
  /// iOS has not been asked yet.
  func requestFix(reason: String, done: ((CLLocation?) -> Void)? = nil) {
    switch authorization {
    case .notDetermined:
      if reason == "foreground" { done?(nil); return }  // a foreground alone never prompts
      log.event("location_permission", ["action": "request", "level": "when_in_use", "for": reason])
      fixer.requestWhenInUseAuthorization()
    case .denied, .restricted:
      done?(nil)
      return
    default:
      break
    }
    // A fix under ten seconds old answers a foreground (the launch's first activation and Places opening).
    if done == nil, let you, -you.timestamp.timeIntervalSinceNow < 10 { return }
    if let done { fixWaiters.append(done) }
    if fixStarted == nil {
      fixStarted = Date()
      log.event("location_fix", ["action": "request", "reason": reason])
      if authorization != .notDetermined { fixer.requestLocation() }
    }
  }

  private func finishFix(_ location: CLLocation?, error: Error? = nil) {
    var fields: [String: Any] = ["action": location == nil ? "failed" : "fix"]
    if let started = fixStarted { fields["ms"] = Int(Date().timeIntervalSince(started) * 1000) }
    if let location {
      fields["accuracy"] = Int(location.horizontalAccuracy.rounded())
      fields["age_s"] = Int(-location.timestamp.timeIntervalSinceNow)
      you = location
    }
    if let error { fields["message"] = "\(error.localizedDescription)" }
    log.event("location_fix", fields)
    fixStarted = nil
    let waiters = fixWaiters
    fixWaiters = []
    waiters.forEach { $0(location) }
  }

  // MARK: - CLLocationManagerDelegate (CoreLocation calls back on the main thread that made the managers)

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    MainActor.assumeIsolated {
      // Every manager hears every change (and its own creation); the recorder speaks for the app.
      guard manager === recorder else { return }
      let status = manager.authorizationStatus
      let before = authorization
      authorization = status
      if before != status {
        log.event("location_permission", ["action": "changed", "from": Self.name(before), "to": Self.name(status)])
      }
      if fixStarted != nil, status == .authorizedWhenInUse || status == .authorizedAlways { fixer.requestLocation() }
      if fixStarted != nil, status == .denied || status == .restricted { finishFix(nil) }
      if wantsTracking {
        switch status {
        case .authorizedAlways: start(reason: "permission")
        case .authorizedWhenInUse: if !askedAlways { askForAlways() }
        case .notDetermined: break
        default: refuse()
        }
      } else if trackingOn && status != .authorizedAlways {
        stop(reason: "permission_lost")
        trackingNote = "Background tracking stopped: iOS now allows location \(permissionText.lowercased())."
      }
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    MainActor.assumeIsolated {
      if manager === fixer {
        finishFix(locations.last)
        return
      }
      record(locations)
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    MainActor.assumeIsolated {
      if manager === fixer {
        finishFix(nil, error: error)
        return
      }
      // Once per spell: kCLErrorLocationUnknown repeats while iOS keeps trying.
      let code = (error as NSError).code
      guard code != lastErrorCode else { return }
      lastErrorCode = code
      log.event("location_error", ["code": code, "message": error.localizedDescription])
    }
  }

  private func record(_ locations: [CLLocation]) {
    guard trackingOn else { return }
    let points = locations.filter { $0.horizontalAccuracy >= 0 }.map {
      LocationPoint(
        latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy,
        timestamp: Geo.ms($0.timestamp))
    }
    guard !points.isEmpty else { return }
    lastErrorCode = nil
    do {
      try store?.insert(points)
      pointsThisLaunch += points.count
      pointsSinceLog += points.count
      logPoints(force: lastPointLog == nil)
    } catch {
      log.event("error", ["where": "location_store", "count": points.count, "message": "\(error)"])
    }
  }

  /// `location_point`: how many points were stored since the last line, never one line per point.
  private func logPoints(force: Bool) {
    let now = Date()
    guard force || now.timeIntervalSince(lastPointLog ?? .distantPast) >= Self.pointLogInterval else { return }
    log.event(
      "location_point",
      [
        "count": pointsSinceLog, "launch_total": pointsThisLaunch,
        "since_ms": lastPointLog.map { Int(now.timeIntervalSince($0) * 1000) } ?? 0,
        "background": UIApplication.shared.applicationState != .active,
      ])
    pointsSinceLog = 0
    lastPointLog = now
  }
}
