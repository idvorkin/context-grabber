//  Box breathing (stories 160–165): inhale, hold, exhale, hold, each one breath length long, for whole cycles.
//
//  Everything derives from one clock reading — the elapsed seconds of the session — so pause and resume never
//  drift and the picture, the sound and the time left always agree. Pure: the app owns the clock and the cues.

import Foundation

public enum BreathPhase: Int, CaseIterable, Equatable, Sendable {
  case inhale, holdFull, exhale, holdEmpty

  /// The word in the circle.
  public var word: String {
    switch self {
    case .inhale: return "Inhale"
    case .exhale: return "Exhale"
    case .holdFull, .holdEmpty: return "Hold"
    }
  }

  /// What the voice says.
  public var spoken: String {
    switch self {
    case .inhale: return "Breathe in"
    case .exhale: return "Breathe out"
    case .holdFull, .holdEmpty: return "Hold"
    }
  }

  public var isHold: Bool { self == .holdFull || self == .holdEmpty }
}

public enum BreathCue: String, CaseIterable, Equatable, Sendable {
  case voice, tone, off

  public var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

public struct BreathPlan: Equatable, Sendable {
  public static let breathRange = 5...15
  public static let sessionRange = 2...15
  public static let defaultBreath = 8
  public static let defaultSession = 5

  /// Seconds on each side of the box.
  public let breathSeconds: Int
  public let cycles: Int

  /// The whole cycles closest to the session length chosen, never fewer than one (story 161).
  public init(breathSeconds: Int, sessionMinutes: Int) {
    let breath = min(Self.breathRange.upperBound, max(Self.breathRange.lowerBound, breathSeconds))
    let session = min(Self.sessionRange.upperBound, max(Self.sessionRange.lowerBound, sessionMinutes))
    self.breathSeconds = breath
    cycles = max(1, Int((Double(session * 60) / Double(4 * breath)).rounded()))
  }

  /// An exact number of cycles, for a launch hook that wants a session shorter than the sliders allow.
  public init(breathSeconds: Int, cycles: Int) {
    self.breathSeconds = max(1, breathSeconds)
    self.cycles = max(1, cycles)
  }

  public var cycleSeconds: Int { 4 * breathSeconds }
  public var totalSeconds: Int { cycles * cycleSeconds }

  /// "4 min 48 s"
  public var lengthText: String { "\(totalSeconds / 60) min \(totalSeconds % 60) s" }
  /// Under the sliders: "9 cycles · ends at 4 min 48 s"
  public var summary: String { "\(cyclesText) · ends at \(lengthText)" }
  /// On Done: "4 min 48 s · 9 cycles"
  public var doneText: String { "\(lengthText) · \(cyclesText)" }
  private var cyclesText: String { cycles == 1 ? "1 cycle" : "\(cycles) cycles" }

  /// Where the session is `elapsed` seconds in.
  public func moment(at elapsed: Double) -> BreathMoment {
    let total = Double(totalSeconds)
    guard elapsed < total else {
      return BreathMoment(
        phase: .holdEmpty, phaseIndex: cycles * 4, cycle: cycles, phaseProgress: 1, ring: 0, scale: 0.9,
        secondsLeft: 0, done: true)
    }
    let t = max(0, elapsed)
    let side = Double(breathSeconds)
    let index = Int(t / side)
    let phase = BreathPhase(rawValue: index % 4) ?? .inhale
    let progress = (t - Double(index) * side) / side
    let ring: Double
    switch phase {
    case .inhale: ring = progress
    case .holdFull: ring = 1
    case .exhale: ring = 1 - progress
    case .holdEmpty: ring = 0
    }
    // Ease in and out on size so a breath feels natural; the ring stays linear so progress reads as time.
    let eased = progress * progress * (3 - 2 * progress)
    let fill: Double
    switch phase {
    case .inhale: fill = eased
    case .holdFull: fill = 1
    case .exhale: fill = 1 - eased
    case .holdEmpty: fill = 0
    }
    return BreathMoment(
      phase: phase, phaseIndex: index, cycle: index / 4 + 1, phaseProgress: progress, ring: ring,
      scale: 0.9 + 0.1 * fill, secondsLeft: totalSeconds - Int(t), done: false)
  }
}

public struct BreathMoment: Equatable, Sendable {
  public let phase: BreathPhase
  /// Phases since the start: 0 is the first inhale. Changes exactly when a cue is due.
  public let phaseIndex: Int
  /// 1-based.
  public let cycle: Int
  /// 0…1 through the current phase; the hold bar's fill.
  public let phaseProgress: Double
  /// 0…1 of the ring drawn: up both sides on the inhale, full on the hold, back down on the exhale.
  public let ring: Double
  /// The circle's size, 0.9…1.
  public let scale: Double
  public let secondsLeft: Int
  public let done: Bool

  /// "4:31 left"
  public var timeLeftText: String { String(format: "%d:%02d left", secondsLeft / 60, secondsLeft % 60) }
}

public enum BreathEffect: Equatable, Sendable {
  /// A phase began: play its cue. `lateMs` is how long after its true time the app noticed.
  case phase(BreathPhase, cycle: Int, lateMs: Int)
  /// The last hold ended.
  case finished(lateMs: Int)
}

/// One session against the caller's clock: start, pause, resume, and what is due at each look.
public struct BreathRun: Equatable, Sendable {
  public let plan: BreathPlan
  /// Seconds of quiet before the first inhale (the voice says "Let's begin" in it).
  public let leadIn: Double
  private var anchor: Double?
  private var banked: Double = 0
  private var lastPhaseIndex = -1
  public private(set) var isFinished = false

  public init(plan: BreathPlan, leadIn: Double = 0) {
    self.plan = plan
    self.leadIn = leadIn
  }

  public var isRunning: Bool { anchor != nil }
  public var isPaused: Bool { anchor == nil && !isFinished && (banked > 0 || lastPhaseIndex >= 0) }

  /// Seconds into the breathing itself; negative during the lead-in.
  public func elapsed(now: Double) -> Double { (anchor.map { now - $0 } ?? 0) + banked - leadIn }

  public func moment(now: Double) -> BreathMoment { plan.moment(at: elapsed(now: now)) }

  public mutating func start(now: Double) {
    guard anchor == nil, !isFinished else { return }
    anchor = now
  }

  public mutating func pause(now: Double) {
    guard let anchor else { return }
    banked += now - anchor
    self.anchor = nil
  }

  /// What became due since the last look. A look after a long gap reports only where the session is now.
  public mutating func tick(now: Double) -> [BreathEffect] {
    guard isRunning, !isFinished else { return [] }
    let t = elapsed(now: now)
    guard t >= 0 else { return [] }
    let m = plan.moment(at: t)
    if m.done {
      isFinished = true
      banked = Double(plan.totalSeconds) + leadIn
      anchor = nil
      return [.finished(lateMs: Int((t - Double(plan.totalSeconds)) * 1000))]
    }
    guard m.phaseIndex != lastPhaseIndex else { return [] }
    lastPhaseIndex = m.phaseIndex
    let due = Double(m.phaseIndex * plan.breathSeconds)
    return [.phase(m.phase, cycle: m.cycle, lateMs: Int((t - due) * 1000))]
  }
}

/// The tone cues, synthesised once into WAV data: a rising tone to breathe in, a falling one to breathe out, a
/// soft tick for a hold, and a closing tone.
public enum BreathTone: String, CaseIterable, Sendable {
  case rising, falling, tick, closing

  public static func tone(for phase: BreathPhase) -> BreathTone {
    switch phase {
    case .inhale: return .rising
    case .exhale: return .falling
    case .holdFull, .holdEmpty: return .tick
    }
  }

  public static let sampleRate = 44100.0

  public var seconds: Double {
    switch self {
    case .rising, .falling: return 0.9
    case .tick: return 0.14
    case .closing: return 1.6
    }
  }

  /// Mono samples in -1…1, faded in and out so nothing clicks.
  public func samples() -> [Float] {
    let count = Int(seconds * Self.sampleRate)
    var out = [Float](repeating: 0, count: count)
    var phase = 0.0
    for i in 0..<count {
      let x = Double(i) / Double(count)
      let hz: Double
      let envelope: Double
      switch self {
      case .rising:
        hz = 330 + (494 - 330) * x
        envelope = sin(Double.pi * x)
      case .falling:
        hz = 494 - (494 - 330) * x
        envelope = sin(Double.pi * x)
      case .tick:
        hz = 660
        envelope = sin(Double.pi * x)
      case .closing:
        hz = 440
        envelope = min(1, x * 40) * exp(-3 * x)
      }
      phase += 2 * Double.pi * hz / Self.sampleRate
      var value = sin(phase)
      if self == .closing { value = 0.6 * value + 0.4 * sin(phase * 1.5) }  // a fifth above, for a settled chord
      out[i] = Float(0.35 * envelope * value)
    }
    return out
  }

  /// A 16-bit mono WAV file in memory.
  public func wav() -> Data {
    let pcm = PCM.floatToPcm16(samples())
    let dataBytes = UInt32(pcm.count * 2)
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
    data.append(contentsOf: Array("RIFF".utf8))
    append(36 + dataBytes)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))  // PCM
    append(UInt16(1))  // mono
    append(UInt32(Self.sampleRate))
    append(UInt32(Self.sampleRate) * 2)
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(dataBytes)
    for sample in pcm { append(sample) }
    return data
  }
}
