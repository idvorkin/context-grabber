//  Story 137 (#177): the eulogy song, played inside the app from the copy it ships with. It plays like music: the
//  session is .playback without mixing, so it pauses what else was playing, carries on with the phone locked
//  (the audio background mode), and the lock screen can pause it.
//
//  ContextCore's SongPlayback decides what play, pause, a seek, the finish and a failure do, and when the audio
//  session is taken and let go; this is its SongPlayer (AVAudioPlayer, the session, the lock screen's remote and
//  now-playing card, the clock) and publishes what it decides.

import AVFoundation
import BugKit
import ContextCore
import MediaPlayer
import SwiftUI

@MainActor
final class EulogySongPlayer: NSObject, ObservableObject {
  static let title = "How Igor wants to live"

  @Published private(set) var isPlaying = false
  @Published private(set) var elapsed: TimeInterval = 0
  @Published private(set) var duration: TimeInterval = 0
  /// What went wrong, copyable with its operation and the player's and session's state (#201).
  @Published private(set) var failure: BugProblem?
  /// Why the song is not playing although asked to: a live call (#197).
  @Published private(set) var waiting: String?
  /// Who holds the audio, if anyone: while it answers, the song neither plays nor touches the session.
  var heldBy: () -> String? {
    get { playback.heldBy }
    set { playback.heldBy = newValue }
  }

  private let log: SessionLog
  private let device: AVSongPlayer
  private let playback: SongPlayback
  private var failuresShown = 0

  /// For the copyable problem's `copy_error` line.
  var bugLogger: BugLogger { log.bugLogger }

  init(log: SessionLog) {
    self.log = log
    device = AVSongPlayer(log: log)
    playback = SongPlayback(player: device)
    super.init()
    playback.onChange = { [weak self] in self?.mirror() }
    device.onFinish = { [weak self] ok in self?.playback.finished(ok: ok) }
    device.remote = { [weak self] command in
      switch command {
      case .play: self?.play(from: "lock_screen")
      case .pause: self?.pause(from: "lock_screen")
      case .toggle: self?.toggle(from: "lock_screen")
      case .seek(let at): self?.seek(to: at, from: "lock_screen")
      }
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
  }

  func play(from source: String) { playback.play(from: source) }
  func pause(from source: String) { playback.pause(from: source) }
  /// A call is starting: pause where the song is, before the call takes the session.
  func yield(to holder: String) { playback.yield(to: holder) }
  func toggle(from source: String) { playback.toggle(from: source) }
  /// Started and not back at the start: what the home screen's small player shows for (#195).
  var isStarted: Bool { playback.isStarted }
  /// The scrubber let go: the song carries on from there, playing or paused as it was.
  func seek(to time: TimeInterval, from source: String) { playback.seek(to: time, from: source) }
  func restart(from source: String) { playback.restart(from: source) }
  /// The small player's ✕: stopped and back at the start, so it goes away.
  func stop(from source: String) { playback.stop(from: source) }

  @objc nonisolated private func interrupted(_ note: Notification) {
    let began =
      (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
    Task { @MainActor in self.playback.interrupted(began: began) }
  }

  /// SongPlayback's state, published; a new failure is drawn with the state around it now.
  private func mirror() {
    if isPlaying != playback.isPlaying { isPlaying = playback.isPlaying }
    if elapsed != playback.elapsed { elapsed = playback.elapsed }
    if duration != playback.duration { duration = playback.duration }
    if waiting != playback.waiting { waiting = playback.waiting }
    if let shown = playback.failure, failuresShown != playback.failures {
      failuresShown = playback.failures
      failure = problem(shown)
    } else if playback.failure == nil, failure != nil {
      failure = nil
    }
  }

  /// The failure on screen with the state around it: where the song was and what the audio session held.
  private func problem(_ failure: SongFailure) -> BugProblem {
    let session = AVAudioSession.sharedInstance()
    var state = failure.extra.mapValues(JSONValue.string)
    state["at_s"] = .double(rounded(device.currentTime))
    state["duration_s"] = .double(rounded(device.duration))
    state["category"] = .string(session.category.rawValue)
    state["mode"] = .string(session.mode.rawValue)
    state["other_audio"] = .bool(session.isOtherAudioPlaying)
    state["outputs"] = .string(
      session.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", "))
    return .grabber(failure.message, context: failure.context, extra: state)
  }

  private func rounded(_ t: TimeInterval) -> Double { (t * 10).rounded() / 10 }
}

/// SongPlayback's player: the bundled song in an AVAudioPlayer, the shared audio session, the lock screen's remote
/// and now-playing card, and the run loop's clock.
@MainActor
private final class AVSongPlayer: NSObject, @preconcurrency SongPlayer, AVAudioPlayerDelegate {
  enum Remote {
    case play, pause, toggle
    case seek(Double)
  }

  private let log: SessionLog
  private var player: AVAudioPlayer?
  private var ticker: Timer?
  private var remoteWired = false
  /// The song ended (true) or the player gave up on it.
  var onFinish: (Bool) -> Void = { _ in }
  /// A lock-screen or Control Center command.
  var remote: (Remote) -> Void = { _ in }

  init(log: SessionLog) {
    self.log = log
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in self.onFinish(flag) }
  }

  func takeSession() -> String? {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
      return nil
    } catch {
      return "\(error)"
    }
  }

  func releaseSession() {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  var sampleRate: Double { AVAudioSession.sharedInstance().sampleRate }
  var hasPlayer: Bool { player != nil }

  func load() -> SongLoad {
    // GRABBER_SONG=missing: the simulator's way to see the failure on screen (#201).
    let name = LaunchHooks.current.songMissing ? "no-such-song" : "eulogy-song"
    guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return .missing }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = TestAudio.volume()
      player.delegate = self
      player.prepareToPlay()
      self.player = player
      wireRemote()
      return .loaded
    } catch {
      return .failed("\(error)")
    }
  }

  func drop() {
    player?.stop()
    player = nil
  }

  var isPlaying: Bool { player?.isPlaying ?? false }
  var currentTime: Double {
    get { player?.currentTime ?? 0 }
    set { player?.currentTime = newValue }
  }
  var duration: Double { player?.duration ?? 0 }
  func play() -> Bool { player?.play() ?? false }
  func pause() { player?.pause() }
  func stop() { player?.stop() }
  func prepare() -> Bool { player?.prepareToPlay() ?? false }

  func audioFields() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    return [
      "sample_rate_hz": session.sampleRate,
      "category": session.category.rawValue,
      "mode": session.mode.rawValue,
      "outputs": session.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(
        separator: ", "),
    ]
  }

  func refusalFields() -> [String: Any] {
    [
      "other_audio": AVAudioSession.sharedInstance().isOtherAudioPlaying,
      "category": AVAudioSession.sharedInstance().category.rawValue,
    ]
  }

  func showNowPlaying(elapsed: Double, duration: Double, playing: Bool) {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: EulogySongPlayer.title,
      MPMediaItemPropertyArtist: "Igor",
      MPMediaItemPropertyPlaybackDuration: duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
    ]
  }

  func startTicking(every seconds: Double, _ look: @escaping () -> Void) {
    ticker?.invalidate()
    // .common so the clock keeps moving while a scroll is tracking.
    let timer = Timer(timeInterval: seconds, repeats: true) { _ in
      MainActor.assumeIsolated { look() }
    }
    RunLoop.main.add(timer, forMode: .common)
    ticker = timer
  }

  func stopTicking() {
    ticker?.invalidate()
    ticker = nil
  }

  var now: Double { Date().timeIntervalSince1970 }

  func log(_ type: String, _ fields: [String: Any]) { log.event(type, fields) }

  /// The lock screen and Control Center: the title, where it is, and play/pause.
  private func wireRemote() {
    guard !remoteWired else { return }
    remoteWired = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.remote(.play) }
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.remote(.pause) }
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      let at = event.positionTime
      Task { @MainActor in self?.remote(.seek(at)) }
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.remote(.toggle) }
      return .success
    }
  }
}

/// The sheet *Eulogy song* opens: the title, play/pause, where it is, and the song on Suno.
struct EulogySongView: View {
  @ObservedObject var song: EulogySongPlayer
  let openOnSuno: () -> Void
  /// Where the finger is while dragging; the song moves when it lets go.
  @State private var scrubbing: TimeInterval?

  var body: some View {
    VStack(spacing: 20) {
      Text(EulogySongPlayer.title).font(.title2.bold()).multilineTextAlignment(.center)
      HStack(spacing: 28) {
        Button {
          song.restart(from: "sheet")
        } label: {
          Image(systemName: "backward.end.fill").font(.title)
        }
        .accessibilityIdentifier("eulogy-song-restart")
        .accessibilityLabel("Restart")
        Button {
          song.toggle(from: "sheet")
        } label: {
          Image(systemName: song.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.yellow)
        }
        .accessibilityIdentifier("eulogy-song-toggle")
        .accessibilityLabel(song.isPlaying ? "Pause" : (song.elapsed > 0 ? "Resume" : "Play"))
        // Balances the restart button so play stays centred.
        Image(systemName: "backward.end.fill").font(.title).hidden()
      }
      VStack(spacing: 4) {
        Slider(
          value: Binding(get: { scrubbing ?? song.elapsed }, set: { scrubbing = $0 }),
          in: 0...max(song.duration, 1)
        ) { editing in
          if !editing, let to = scrubbing {
            song.seek(to: to, from: "sheet")
            scrubbing = nil
          }
        }
        .tint(.yellow)
        .accessibilityIdentifier("eulogy-song-scrubber")
        HStack {
          Text(Self.clock(scrubbing ?? song.elapsed)).accessibilityIdentifier("eulogy-song-elapsed")
          Spacer()
          Text(Self.clock(song.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      }
      if let waiting = song.waiting {
        Text(waiting).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("eulogy-song-waiting")
      }
      if let failure = song.failure {
        BugProblemView(problem: failure, logger: song.bugLogger).accessibilityIdentifier("eulogy-song-failure")
      }
      Button("Open on Suno", action: openOnSuno)
        .font(.footnote)
        .accessibilityIdentifier("eulogy-song-suno")
    }
    .padding(24)
    .presentationDetents([.height(340)])
  }

  static func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}

/// #195: the song, small, in the home screen's bottom-left corner while it plays or is paused partway.
struct EulogyMiniPlayer: View {
  @ObservedObject var song: EulogySongPlayer
  let open: () -> Void

  var body: some View {
    if song.isStarted {
      HStack(spacing: 10) {
        Button(action: open) {
          HStack(spacing: 6) {
            Image(systemName: "music.note").foregroundStyle(.yellow)
            Text(EulogySongView.clock(song.elapsed)).font(.caption.monospacedDigit())
          }
        }
        .accessibilityIdentifier("eulogy-mini-open")
        .accessibilityLabel("Eulogy song, \(EulogySongView.clock(song.elapsed))")
        Button {
          song.toggle(from: "mini")
        } label: {
          Image(systemName: song.isPlaying ? "pause.fill" : "play.fill")
        }
        .accessibilityIdentifier("eulogy-mini-toggle")
        .accessibilityLabel(song.isPlaying ? "Pause" : "Resume")
        Button {
          song.stop(from: "mini")
        } label: {
          Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("eulogy-mini-stop")
        .accessibilityLabel("Stop")
      }
      .font(.title3)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.regularMaterial, in: Capsule())
      .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
  }
}
