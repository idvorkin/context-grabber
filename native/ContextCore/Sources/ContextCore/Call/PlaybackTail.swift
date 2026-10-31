//  #578: a heal's rebuild threw away what the old player had queued, so a speaker that took more than two seconds
//  to start lost Tony's whole greeting, and a mid-reply microphone reset lost the rest of Larry's sentence (#577:
//  13.7 s). The engine keeps a copy of what it schedules, on the player's own timeline, and after a rebuild plays
//  the part the old player had not reached.

/// Larry's samples as scheduled, each chunk at the player time it starts.
public struct PlaybackTail: Sendable {
  private var chunks: [(start: Double, samples: [Float])] = []
  public let rate: Double

  public init(rate: Double) { self.rate = rate }

  /// A chunk scheduled to start at `start` seconds of player time.
  public mutating func append(_ samples: [Float], at start: Double) {
    guard !samples.isEmpty else { return }
    chunks.append((start, samples))
  }

  /// Forget the chunks the player has finished with by `time`, so a long call holds only what is ahead.
  public mutating func prune(before time: Double) {
    chunks.removeAll { $0.start + Double($0.samples.count) / rate <= time }
  }

  /// What the player had not played by `time`, in order: a gap between chunks (a starved queue) is not kept.
  public func unplayed(at time: Double) -> [Float] {
    var out: [Float] = []
    for chunk in chunks {
      let skip = max(0, Int(((time - chunk.start) * rate).rounded(.down)))
      guard skip < chunk.samples.count else { continue }
      out.append(contentsOf: chunk.samples[skip...])
    }
    return out
  }

  /// Seconds of samples held, gaps not counted.
  public var durationS: Double { Double(chunks.reduce(0) { $0 + $1.samples.count }) / rate }

  /// Keep only what was unheard at `time`, as one chunk from zero: the new player's timeline. A rebuild that fails
  /// and is tried again finds the same tail, so nothing heard comes back twice.
  public mutating func rebase(at time: Double) {
    let rest = unplayed(at: time)
    chunks = rest.isEmpty ? [] : [(0, rest)]
  }

  /// A barge-in or a new stream: nothing queued is Larry's to finish.
  public mutating func reset() { chunks = [] }
}
