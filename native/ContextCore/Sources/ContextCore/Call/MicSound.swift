//  Stories 1082 and 1083 (context-grabber-ka1i): how the call's microphone sounded, measured on exactly the audio the
//  call sends (after the phone's voice processing). Every tenth of a second is a piece: its RMS and peak, whether it
//  clipped, whether it was digital silence. Five seconds of pieces make a window: the noise floor is the quiet pieces'
//  level (the 10th percentile, as Audio Debugger's readout takes it), the speech level the loud ones' (the 90th), and
//  the score the spec's four parts. Plain loops, no Accelerate: ContextCore builds on Linux too.
//  Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md#how-the-mic-sounds.

import Foundation

public struct MicSound {
  /// One window's reading: nil levels when it held no pieces with sound.
  public struct Window: Equatable {
    public var pieces = 0
    public var floorDB: Double?
    public var speechDB: Double?
    public var snrDB: Double?
    public var peakDB: Double = MicSound.silenceDB
    public var clips = 0
    public var dropouts = 0
    public var score = 0
    public var speech: Bool { snrDB != nil }

    /// The `call_stats` fields, prefixed `mic_`; nothing at all for a window with no pieces.
    public var fields: [String: Any] {
      guard pieces > 0 else { return [:] }
      var out: [String: Any] = [
        "mic_pieces": pieces, "mic_clips": clips, "mic_dropouts": dropouts, "mic_score": score,
        "mic_peak_db": MicSound.round1(peakDB), "mic_speech": speech,
      ]
      if let floorDB { out["mic_floor_db"] = MicSound.round1(floorDB) }
      if let speechDB { out["mic_speech_db"] = MicSound.round1(speechDB) }
      if let snrDB { out["mic_snr_db"] = MicSound.round1(snrDB) }
      return out
    }
  }

  /// The call's summary at its ending (story 1083).
  public struct Summary: Equatable {
    public var windows = 0
    public var score: Int?
    public var worst: Int?
    public var floorDB: Double?
    public var snrDB: Double?
    public var speech = false

    public var fields: [String: Any] {
      var out: [String: Any] = ["windows": windows, "speech": speech]
      if let score { out["score"] = score }
      if let worst { out["worst"] = worst }
      if let floorDB { out["floor_db"] = MicSound.round1(floorDB) }
      if let snrDB { out["snr_db"] = MicSound.round1(snrDB) }
      return out
    }
  }

  static let silenceDB = -200.0
  /// Full scale, near enough: a piece whose loudest sample reaches this clipped.
  static let clipLevel: Float = 0.999
  /// Speech less than this far over the floor is no speech.
  static let speechOverFloorDB = 6.0
  /// Half of five seconds' pieces: a shorter window counts toward the call only when it has nothing longer.
  static let countedPieces = 25

  private var partial: [Float] = []
  private var levels: [Double] = []
  private var peak: Float = 0
  private var pieces = 0
  private var clips = 0
  private var dropouts = 0
  private var windows: [Window] = []

  public init() {}

  /// A buffer of the call's mic samples, at the rate it came at; pieces span buffers.
  public mutating func add(_ samples: [Float], sampleRate: Double) {
    let size = max(1, Int((sampleRate / 10).rounded()))
    partial.append(contentsOf: samples)
    var start = 0
    while partial.count - start >= size {
      measure(partial[start..<(start + size)])
      start += size
    }
    if start > 0 { partial.removeFirst(start) }
  }

  private mutating func measure(_ piece: ArraySlice<Float>) {
    pieces += 1
    var sum: Double = 0
    var loudest: Float = 0
    for sample in piece {
      sum += Double(sample) * Double(sample)
      loudest = max(loudest, abs(sample))
    }
    peak = max(peak, loudest)
    if loudest == 0 {
      dropouts += 1
      return
    }
    if loudest >= Self.clipLevel { clips += 1 }
    levels.append(Self.decibels((sum / Double(piece.count)).squareRoot()))
  }

  /// The window since the last close, and starts the next; kept for the call's summary when it had pieces.
  public mutating func closeWindow() -> Window {
    var window = Window(pieces: pieces, clips: clips, dropouts: dropouts)
    window.peakDB = Self.decibels(Double(peak))
    if !levels.isEmpty {
      let sorted = levels.sorted()
      let floor = sorted[sorted.count / 10]
      let loud = sorted[min(sorted.count - 1, sorted.count * 9 / 10)]
      window.floorDB = floor
      if loud - floor >= Self.speechOverFloorDB {
        window.speechDB = loud
        window.snrDB = loud - floor
      }
    }
    if pieces > 0 {
      window.score = Self.score(
        snrDB: window.snrDB, floorDB: window.floorDB,
        clipFraction: Double(clips) / Double(pieces), dropoutFraction: Double(dropouts) / Double(pieces))
      windows.append(window)
    }
    levels = []
    peak = 0
    pieces = 0
    clips = 0
    dropouts = 0
    return window
  }

  /// The whole call: the median window score, so one gust doesn't sink it; the worst window; the median floor and SNR.
  public func callSummary() -> Summary {
    let long = windows.filter { $0.pieces >= Self.countedPieces }
    let windows = long.isEmpty ? self.windows : long
    var summary = Summary(windows: windows.count)
    guard !windows.isEmpty else { return summary }
    summary.score = Self.median(windows.map { Double($0.score) }).map { Int($0.rounded()) }
    summary.worst = windows.map(\.score).min()
    summary.floorDB = Self.median(windows.compactMap(\.floorDB))
    summary.snrDB = Self.median(windows.compactMap(\.snrDB))
    summary.speech = windows.contains { $0.speech }
    return summary
  }

  /// The spec's score: SNR 50 points (30 dB full, 0 dB none), floor 20 (−60 dBFS full, −30 none), clipping 15 (none
  /// full, 10% of pieces none), dropouts 15 (none full, 20% none); each linear. No speech: the other three, scaled to 100.
  /// No floor, every piece digital silence: 0.
  public static func score(snrDB: Double?, floorDB: Double?, clipFraction: Double, dropoutFraction: Double) -> Int {
    guard let floorDB else { return 0 }
    func part(_ points: Double, _ value: Double, full: Double, zero: Double) -> Double {
      let t = (value - zero) / (full - zero)
      return points * min(1, max(0, t))
    }
    let floor = part(20, floorDB, full: -60, zero: -30)
    let clipping = part(15, clipFraction, full: 0, zero: 0.1)
    let dropouts = part(15, dropoutFraction, full: 0, zero: 0.2)
    guard let snrDB else { return Int(((floor + clipping + dropouts) * 2).rounded()) }
    return Int((part(50, snrDB, full: 30, zero: 0) + floor + clipping + dropouts).rounded())
  }

  static func decibels(_ amplitude: Double) -> Double { amplitude > 0 ? 20 * log10(amplitude) : silenceDB }
  static func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

  static func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let mid = sorted.count / 2
    return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
  }
}
