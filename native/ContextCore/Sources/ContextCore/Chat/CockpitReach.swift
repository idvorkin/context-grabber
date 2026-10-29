//  #565 (spec 2026-10-25-native-chat-design.md, When the Cockpit isn't answering): a request that timed out or could
//  not connect while the phone is online means the Cockpit is away, not the phone or the app.

import Foundation

public enum CockpitReach {
  public static let away = "The Cockpit isn't answering — your messages are kept and go when it does"

  static let awayCodes: Set<URLError.Code> = [
    .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost,
    .notConnectedToInternet,
  ]

  public static func isAway(_ error: Error) -> Bool {
    guard let error = error as? URLError else { return false }
    return awayCodes.contains(error.code)
  }

  /// What a failed read says: the plain line when the Cockpit is away, with the reason kept for the copy.
  public static func problem(_ error: Error, otherwise: String) -> String {
    isAway(error) ? "\(away). (\(error.localizedDescription))" : "\(otherwise): \(error.localizedDescription)"
  }
}
