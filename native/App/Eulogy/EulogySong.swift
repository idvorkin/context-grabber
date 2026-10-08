//  Story 137 (#177): the eulogy song, played inside the app from the copy it ships with. It plays like music: the
//  session is .playback without mixing, so it pauses what else was playing, carries on with the phone locked
//  (the audio background mode), and the lock screen can pause it.

import AVFoundation
import MediaPlayer
import SwiftUI

@MainActor
final class EulogySongPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
  static let title = "How Igor wants to live"

  @Published private(set) var isPlaying = false
  @Published private(set) var elapsed: TimeInterval = 0
  @Published private(set) var duration: TimeInterval = 0
  @Published private(set) var failure: String?

  private let log: SessionLog
  private var player: AVAudioPlayer?
  private var ticker: Timer?
  private var remoteWired = false

  init(log: SessionLog) {
    self.log = log
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
  }

  func play(from source: String) {
    guard let player = loaded() else { return }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      log.event("eulogy_song", ["action": "session", "ok": false, "message": "\(error)"])
    }
    var ok = player.play()
    var how = "play"
    if !ok {
      // A paused player can refuse; re-preparing it at the same place is the retry, and a fresh one the last.
      let at = player.currentTime
      log.event(
        "eulogy_song",
        ["action": "play_refused", "at": rounded(at), "prepared": player.prepareToPlay(),
         "other_audio": AVAudioSession.sharedInstance().isOtherAudioPlaying,
         "category": AVAudioSession.sharedInstance().category.rawValue])
      ok = player.play()
      how = "re_prepared"
      if !ok {
        self.player = nil
        if let fresh = loaded() {
          fresh.currentTime = at
          ok = fresh.play()
          how = "fresh_player"
        }
      }
    }
    let current = self.player ?? player
    log.event("eulogy_song", ["action": "play", "from": source, "at": rounded(current.currentTime), "ok": ok, "how": how])
    failure = ok ? nil : "The song would not start; the log says why."
    sync()
  }

  func pause(from source: String) {
    guard let player, player.isPlaying else { return }
    player.pause()
    log.event("eulogy_song", ["action": "pause", "from": source, "at": rounded(player.currentTime)])
    sync()
  }

  func toggle(from source: String) {
    if isPlaying { pause(from: source) } else { play(from: source) }
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in
      player.currentTime = 0
      self.log.event("eulogy_song", ["action": "finished", "ok": flag])
      self.sync()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  @objc nonisolated private func interrupted(_ note: Notification) {
    let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
    Task { @MainActor in
      guard let player = self.player else { return }
      self.log.event("eulogy_song", ["action": began ? "interrupted" : "interruption_ended", "at": self.rounded(player.currentTime)])
      self.sync()
    }
  }

  private func loaded() -> AVAudioPlayer? {
    if let player { return player }
    guard let url = Bundle.main.url(forResource: "eulogy-song", withExtension: "mp3") else {
      failure = "The song is missing from this build."
      log.event("eulogy_song", ["action": "load", "ok": false, "message": "eulogy-song.mp3 not in the bundle"])
      return nil
    }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      player.prepareToPlay()
      self.player = player
      duration = player.duration
      failure = nil
      wireRemote()
      return player
    } catch {
      failure = "The song would not load; the log says why."
      log.event("eulogy_song", ["action": "load", "ok": false, "message": "\(error)"])
      return nil
    }
  }

  /// The lock screen and Control Center: the title, where it is, and play/pause.
  private func wireRemote() {
    guard !remoteWired else { return }
    remoteWired = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.play(from: "lock_screen") }
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.pause(from: "lock_screen") }
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.toggle(from: "lock_screen") }
      return .success
    }
  }

  private func sync() {
    guard let player else { return }
    isPlaying = player.isPlaying
    elapsed = player.currentTime
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: Self.title,
      MPMediaItemPropertyArtist: "Igor",
      MPMediaItemPropertyPlaybackDuration: player.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
      MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
    ]
    if isPlaying, ticker == nil {
      // .common so the clock keeps moving while a scroll is tracking.
      let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tick() }
      }
      RunLoop.main.add(timer, forMode: .common)
      ticker = timer
    } else if !isPlaying {
      ticker?.invalidate()
      ticker = nil
    }
  }

  private func tick() {
    guard let player else { return }
    elapsed = player.currentTime
    if player.isPlaying != isPlaying { sync() }
  }

  private nonisolated func rounded(_ t: TimeInterval) -> Double { (t * 10).rounded() / 10 }
}

/// The sheet *Eulogy song* opens: the title, play/pause, where it is, and the song on Suno.
struct EulogySongView: View {
  @ObservedObject var song: EulogySongPlayer
  let openOnSuno: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text(EulogySongPlayer.title).font(.title2.bold()).multilineTextAlignment(.center)
      Button {
        song.toggle(from: "sheet")
      } label: {
        Image(systemName: song.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 72))
          .foregroundStyle(.yellow)
      }
      .accessibilityIdentifier("eulogy-song-toggle")
      .accessibilityLabel(song.isPlaying ? "Pause" : (song.elapsed > 0 ? "Resume" : "Play"))
      VStack(spacing: 4) {
        ProgressView(value: song.duration > 0 ? min(song.elapsed / song.duration, 1) : 0)
        HStack {
          Text(Self.clock(song.elapsed)).accessibilityIdentifier("eulogy-song-elapsed")
          Spacer()
          Text(Self.clock(song.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      }
      if let failure = song.failure {
        Text(failure).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("eulogy-song-failure")
      }
      Button("Open on Suno", action: openOnSuno)
        .font(.footnote)
        .accessibilityIdentifier("eulogy-song-suno")
    }
    .padding(24)
    .presentationDetents([.height(320)])
  }

  static func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}
