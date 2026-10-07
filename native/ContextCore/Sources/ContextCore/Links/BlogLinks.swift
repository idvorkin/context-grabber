//  Igor's blog from the home screen (story 137; spec 2026-10-07-native-eulogy-design.md): the eulogy post, its song,
//  and the recent changes.

import Foundation

public enum BlogLinks {
  public static let eulogy = URL(string: "https://idvork.in/eulogy")!
  public static let recent = URL(string: "https://idvork.in/recent")!

  /// The Suno song the post embeds, as its song page (which the Suno app opens): the post carries it as an embed
  /// (`suno.com/embed/<id>`) and as a link (`suno.com/song/<id>`). The first one wins; nil when there is none.
  public static func song(inPost html: String) -> URL? {
    let pattern = #"suno\.com/(?:song|embed)/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
      let id = Range(match.range(at: 1), in: html)
    else { return nil }
    return URL(string: "https://suno.com/song/\(html[id].lowercased())")
  }
}
