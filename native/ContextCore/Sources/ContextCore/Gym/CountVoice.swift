//  Who says the Gym Timer's count (story 182): Adam by default, Igor's own clone, or an excited Australian woman.
//  Remembered in the settings table; each voice is six sound files in the bundle (scripts/make-timer-voice.sh).

public enum CountVoice: String, CaseIterable, Sendable {
  case adam, igor, aussie

  public static let `default` = CountVoice.adam
  public static let settingKey = "gym_count_voice"

  /// The remembered value, or the default when nothing (or something unknown) was stored.
  public static func decode(_ raw: String?) -> CountVoice {
    raw.flatMap(CountVoice.init(rawValue:)) ?? .default
  }

  /// The row in Timer settings.
  public var label: String {
    switch self {
    case .adam: "Adam"
    case .igor: "Igor"
    case .aussie: "Australian woman"
    }
  }

  /// The cue's sound file, without `.wav`: Igor's set is the React Native app's (`three`), the others are
  /// prefixed (`adam-three`).
  public func fileName(for cue: TimerCue) -> String {
    self == .igor ? cue.rawValue : "\(rawValue)-\(cue.rawValue)"
  }
}
