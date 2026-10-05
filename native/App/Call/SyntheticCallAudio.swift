//  A call's audio with no hardware, for the simulator smoke run (`GRABBER_CALL_AUDIO=synthetic`): the "mic" is a
//  220 Hz tone at 48 kHz in 100 ms buffers, and Larry's frames are counted and "played" at real time. It checks the
//  call's protocol path — start frame, frames up, PCM down, captions, the hang-up — where the simulator's own audio
//  cannot be trusted (docs/TESTING.md). Never used on the phone unless the hook asks for it.

import ContextCore
import Foundation

final class SyntheticCallAudio: CallAudio {
  var onHealth: ((String?) -> Void)?

  private let log: (String, [String: Any]) -> Void
  private var mic: Timer?
  private var phase = 0.0
  private var outRate = 24000.0
  private var scheduledS = 0.0
  private var openedAt: Date?

  init(log: @escaping (String, [String: Any]) -> Void) {
    self.log = log
  }

  func prepare(_ done: @escaping (Error?) -> Void) {
    log("call_audio", ["action": "session", "ok": true, "synthetic": true])
    done(nil)
  }

  func startMic(_ onBuffer: @escaping ([Float], Double) -> Void, _ done: @escaping (Error?) -> Void) {
    mic?.invalidate()
    log("call_audio", ["action": "mic_arm", "rate": 48000.0, "channels": 1, "synthetic": true])
    mic = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      guard let self else { return }
      var samples = [Float](repeating: 0, count: 4800)
      for i in samples.indices {
        samples[i] = Float(0.2 * sin(self.phase))
        self.phase += 2 * Double.pi * 220 / 48000
      }
      onBuffer(samples, 48000)
    }
    done(nil)
  }

  func restartMic(_ done: @escaping (Error?) -> Void) {
    log("call_audio", ["action": "restart", "why": "heal", "synthetic": true])
    done(nil)
  }

  func openPlayback(outRate: Double) {
    self.outRate = outRate
    scheduledS = 0
    openedAt = Date()
    log("call_audio", ["action": "playback_open", "out_rate": outRate, "ok": true, "synthetic": true])
  }

  func play(_ pcm: Data) {
    scheduledS += Double(pcm.count / 2) / outRate
  }

  func flush() {
    scheduledS = min(scheduledS, playedS)
  }

  func stop() {
    mic?.invalidate()
    mic = nil
    openedAt = nil
    log("call_audio", ["action": "inactive", "ok": true, "synthetic": true])
  }

  private var playedS: Double { min(scheduledS, openedAt.map { Date().timeIntervalSince($0) } ?? 0) }

  func stats() -> PlaybackStats? {
    guard openedAt != nil else { return nil }
    return PlaybackStats(scheduledS: scheduledS, playedS: playedS, clockRunning: true, pendingS: 0)
  }
}

/// The wall clock and main-queue timers, for CallSession.
final class MainScheduler: CallScheduler {
  final class Item: CallTimer {
    let work: DispatchWorkItem
    init(_ work: DispatchWorkItem) { self.work = work }
    func cancel() { work.cancel() }
  }

  var now: Double { Date().timeIntervalSince1970 * 1000 }

  func after(_ ms: Double, _ block: @escaping () -> Void) -> CallTimer {
    let work = DispatchWorkItem(block: block)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(ms)), execute: work)
    return Item(work)
  }
}
