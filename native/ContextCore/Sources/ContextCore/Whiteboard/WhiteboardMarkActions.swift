//  The choices beside a reply of Larry's (spec 2026-11-01-whiteboard-shapes-design.md, *Larry chooses the buttons
//  beside his reply*; stories 1352, 1353, #1525). A reply names them, in order, so a new choice reaches the board
//  without a new build; the board shows the ones it knows. Pure: no UI.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum WhiteboardMarkActions {
  /// A choice this build can do.
  public enum Action: String, Codable, Equatable, Sendable, CaseIterable {
    case keep
    case dismiss
    // To question/answer ("qa", story 1354) is not built yet: offered, it is left out as one this build doesn't know.
  }

  /// One button: a choice and the reply's label for it, if it gave one.
  public struct Offer: Codable, Equatable, Sendable {
    public let action: Action
    public let label: String?

    public init(action: Action, label: String? = nil) {
      self.action = action
      self.label = label
    }

    /// What the button reads: the reply's label, or the board's own name (a group's for a reply of several marks).
    public func title(group: Bool) -> String {
      if let label, !label.isEmpty { return label }
      switch action {
      case .keep: return group ? "Keep group" : "Keep"
      case .dismiss: return group ? "Dismiss group" : "Dismiss"
      }
    }
  }

  /// What a reply offered: the buttons to show, and the choices this build doesn't know (for the session log).
  public struct Offered: Equatable, Sendable {
    public let offers: [Offer]
    public let unknown: [String]
  }

  /// The unknown choices as the session log may carry them: at most 4, each cut to 24 characters, so a reply can't fill
  /// a bug report with its own words.
  public static func logged(_ unknown: [String]) -> [String] { unknown.prefix(4).map { String($0.prefix(24)) } }

  /// Keep and Dismiss: a reply that names no choice, or none this build knows.
  public static let standard = [Offer(action: .keep), Offer(action: .dismiss)]

  /// A reply's `actions`: a list of `{id, label?}` or plain ids. Missing, empty or all unknown gives Keep and Dismiss,
  /// so a mark can always be kept or dismissed; a choice named twice shows once.
  public static func parse(_ json: Any?) -> Offered {
    guard let list = json as? [Any] else { return Offered(offers: standard, unknown: []) }
    var offers: [Offer] = []
    var unknown: [String] = []
    for item in list {
      let id: String?
      let label: String?
      if let s = item as? String {
        (id, label) = (s, nil)
      } else if let o = item as? [String: Any] {
        (id, label) = (o["id"] as? String, o["label"] as? String)
      } else {
        (id, label) = (nil, nil)
      }
      guard let id else { continue }
      guard let action = Action(rawValue: id) else {
        unknown.append(id)
        continue
      }
      if offers.contains(where: { $0.action == action }) { continue }
      offers.append(Offer(action: action, label: label))
    }
    return Offered(offers: offers.isEmpty ? standard : offers, unknown: unknown)
  }
}
