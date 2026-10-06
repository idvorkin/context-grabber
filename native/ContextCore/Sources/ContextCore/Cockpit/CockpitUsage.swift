//  The usage strip on the home screen (story 203; spec docs/superpowers/specs/2026-10-05-native-cockpit-design.md,
//  "The usage strip"): the Cockpit's `GET /usage` reading, and what the strip draws from it — what is LEFT.
//
//  The Cockpit's rule carries over: a reading it does not have is drawn as nothing, never as 0%, and an old one says
//  its age rather than looking current.

import Foundation

/// `GET /usage` as the Cockpit serves it. Every field is optional: a missing one is "not known".
public struct CockpitUsage: Codable, Equatable, Sendable {
  public var present: Bool?
  /// Percent USED, 0–100.
  public var weeklyPct: Double?
  public var modelPct: Double?
  /// Readings written before the model got its own name carry only this.
  public var fablePct: Double?
  public var modelName: String?
  public var resetsIn: String?
  /// The weekly reset as an ISO instant with its offset ("2026-10-05T21:59:59-07:00").
  public var resets: String?
  public var pacing: String?
  public var age: String?
  public var stale: Bool?
  /// A refresh asked for and not yet landed.
  public var pending: Bool?
  /// ElevenLabs, percent USED.
  public var elPct: Double?
  public var elMinutesLeft: Double?
  public var elResetsIn: String?
  public var elAge: String?
  public var elStale: Bool?

  enum CodingKeys: String, CodingKey {
    case present, pacing, age, stale, pending, resets
    case weeklyPct = "weekly_pct", modelPct = "model_pct", fablePct = "fable_pct", modelName = "model_name"
    case resetsIn = "resets_in", elPct = "el_pct", elMinutesLeft = "el_minutes_left", elResetsIn = "el_resets_in"
    case elAge = "el_age", elStale = "el_stale"
  }

  public init(
    present: Bool? = nil, weeklyPct: Double? = nil, modelPct: Double? = nil, fablePct: Double? = nil,
    modelName: String? = nil, resetsIn: String? = nil, resets: String? = nil, pacing: String? = nil, age: String? = nil,
    stale: Bool? = nil, pending: Bool? = nil, elPct: Double? = nil, elMinutesLeft: Double? = nil,
    elResetsIn: String? = nil, elAge: String? = nil, elStale: Bool? = nil
  ) {
    self.present = present; self.weeklyPct = weeklyPct; self.modelPct = modelPct; self.fablePct = fablePct
    self.modelName = modelName; self.resetsIn = resetsIn; self.resets = resets; self.pacing = pacing; self.age = age
    self.stale = stale; self.pending = pending; self.elPct = elPct; self.elMinutesLeft = elMinutesLeft
    self.elResetsIn = elResetsIn; self.elAge = elAge; self.elStale = elStale
  }

  public static func decode(_ data: Data) throws -> CockpitUsage {
    try JSONDecoder().decode(CockpitUsage.self, from: data)
  }
}

/// What the strip draws.
public struct UsageStrip: Equatable, Sendable {
  public enum Level: String, Sendable { case ok, low, critical }

  public struct Bar: Equatable, Sendable {
    public var label: String
    /// Fraction left, 0…1.
    public var left: Double
    public var text: String
    public var level: Level
  }

  public var bars: [Bar]
  /// "resets in 14H · On track", or the reading's age when it is stale.
  public var claudeNote: String?
  public var claudeStale: Bool
  /// "voice resets in 23D10H", or its age when stale.
  public var voiceNote: String?
  public var voiceStale: Bool
  /// "31% to spend" when the week resets within a day with more than 20% left: quota about to go to waste.
  public var spendNote: String?

  /// Under a day to the reset and more than this left: say it is there to spend.
  public static let spendWithinHours = 24.0
  public static let spendAbove = 0.2

  /// Under 20% left is low, under 10% critical.
  public static func level(left: Double) -> Level {
    left < 0.1 ? .critical : left < 0.2 ? .low : .ok
  }

  /// Nil when there is nothing to draw: no Claude reading and no voice reading.
  public init?(_ u: CockpitUsage, now: Date = Date()) {
    var bars: [Bar] = []
    func percentBar(_ label: String, used: Double) -> Bar {
      let left = max(0, min(1, 1 - used / 100))
      return Bar(label: label, left: left, text: "\(Int((left * 100).rounded()))%", level: Self.level(left: left))
    }
    let claude = u.present == true
    if claude, let w = u.weeklyPct { bars.append(percentBar("Week", used: w)) }
    if claude, let m = u.modelPct ?? u.fablePct {
      let name = u.modelName.flatMap { $0.isEmpty ? nil : $0 } ?? (u.modelPct == nil ? "Fable" : "Model")
      bars.append(percentBar(name, used: m))
    }
    let claudeDrawn = !bars.isEmpty
    var voiceDrawn = false
    if let el = u.elPct {
      var bar = percentBar("Voice", used: el)
      if let minutes = u.elMinutesLeft { bar.text = Self.duration(minutes: minutes) }
      bars.append(bar)
      voiceDrawn = true
    }
    guard !bars.isEmpty else { return nil }
    self.bars = bars

    claudeStale = claudeDrawn && u.stale == true
    spendNote = nil
    if claudeDrawn, !claudeStale, let w = u.weeklyPct, let at = u.resets.flatMap(Self.instant) {
      let left = max(0, min(1, 1 - w / 100))
      let hours = at.timeIntervalSince(now) / 3600
      if hours > 0, hours < Self.spendWithinHours, left > Self.spendAbove {
        spendNote = "\(Int((left * 100).rounded()))% to spend"
      }
    }
    if !claudeDrawn {
      claudeNote = nil
    } else if claudeStale {
      claudeNote = u.age.flatMap { $0.isEmpty ? nil : "\($0) old" } ?? "old reading"
    } else {
      let parts = [u.resetsIn.flatMap { $0.isEmpty ? nil : "resets in \($0)" }, u.pacing.flatMap { $0.isEmpty ? nil : $0 }]
        .compactMap { $0 }
      claudeNote = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    voiceStale = voiceDrawn && u.elStale == true
    if !voiceDrawn {
      voiceNote = nil
    } else if voiceStale {
      voiceNote = "voice " + (u.elAge.flatMap { $0.isEmpty ? nil : "\($0) old" } ?? "reading old")
    } else {
      voiceNote = u.elResetsIn.flatMap { $0.isEmpty ? nil : "voice resets in \($0)" }
    }
  }

  static func instant(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: s)
  }

  /// Hours with one decimal from an hour up ("3.8h"), whole minutes under it ("45m").
  public static func duration(minutes: Double) -> String {
    let m = max(0, minutes)
    if m >= 60 { return String(format: "%.1fh", m / 60) }
    return "\(Int(m.rounded()))m"
  }
}
