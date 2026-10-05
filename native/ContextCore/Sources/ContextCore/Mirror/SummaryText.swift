//  The words and numbers the mirror writes: short clock times, grouped numbers, the one-line summary banner.
//  Port of lib/summary.ts.

import Foundation

public enum SummaryText {
  /// "11pm", "6:15am" in UTC — what the export writes for bedtime and wake (kept as the React Native app has it;
  /// see the spec's step 4).
  public static func formatTime(_ iso: String) -> String {
    guard let ms = parseISO(iso) else { return "" }
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let c = utc.dateComponents([.hour, .minute], from: jsDate(ms))
    return clock(c.hour ?? 0, c.minute ?? 0)
  }

  /// The same on the phone's wall clock, for the screen.
  public static func formatLocalTime(_ iso: String, clock local: LocalClock) -> String {
    guard let ms = parseISO(iso) else { return "" }
    return clock(local.hour(ms), local.minute(ms))
  }

  static func clock(_ hours: Int, _ minutes: Int) -> String {
    let period = hours >= 12 ? "pm" : "am"
    let display = hours % 12 == 0 ? 12 : hours % 12
    return minutes == 0 ? "\(display)\(period)" : String(format: "%d:%02d%@", display, minutes, period)
  }

  /// toLocaleString("en-US"): "8,241"; up to `maxFractionDigits` decimals, halves away from zero.
  public static func formatNumber(_ n: Double, maxFractionDigits: Int = 3) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "en_US")
    f.numberStyle = .decimal
    f.maximumFractionDigits = maxFractionDigits
    f.minimumFractionDigits = 0
    f.roundingMode = .halfUp
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
  }

  /// A number as JavaScript prints it in a template string: 7.5, 181, 0.85.
  public static func js(_ n: Double) -> String { JSValue.formatNumber(n) }

  /// "8,241 steps | Slept 7.2hrs (6am–1:15pm) | 62 bpm | …": what was there today, in one line.
  public static func buildSummary(_ h: HealthData, locationCount: Int) -> String {
    var parts: [String] = []
    if let steps = h.steps { parts.append("\(formatNumber(steps)) steps") }
    if let sleep = h.sleepHours {
      var part = "Slept \(js(sleep))hrs"
      if let bed = h.bedtime, let wake = h.wakeTime { part += " (\(formatTime(bed))\u{2013}\(formatTime(wake)))" }
      parts.append(part)
    }
    if let hr = h.heartRate { parts.append("\(js(hr)) bpm") }
    if let energy = h.activeEnergy { parts.append("\(formatNumber(energy)) kcal") }
    if let distance = h.walkingDistance { parts.append("\(js(distance)) km") }
    if let weight = h.weight { parts.append("\(js(jsRound(weight * 2.20462))) lbs") }
    if !h.workouts.isEmpty {
      parts.append(
        h.workouts.map { w in
          var s = "\(w.activityType) \(js(w.durationMinutes))min"
          if let e = w.energyBurned, e != 0 { s += " \(js(e))kcal" }
          if let d = w.distanceKm, d != 0 { s += " \(js(d))km" }
          return s
        }.joined(separator: ", "))
    } else if let exercise = h.exerciseMinutes {
      parts.append("\(js(exercise)) min exercise")
    }
    if let meditation = h.meditationMinutes { parts.append("\(js(meditation)) min meditation") }
    if locationCount > 0 { parts.append("\(formatNumber(Double(locationCount))) locations") }
    return parts.joined(separator: " | ")
  }
}
