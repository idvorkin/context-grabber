//  Which build this is. The justfile's build recipes pass GIT_SHA and GIT_BRANCH to xcodebuild and Info.plist
//  carries them; a build from Xcode's Run button reads "dev".

import Foundation

enum BuildInfo {
  static let sha = info("GitSha")
  static let branch = info("GitBranch")
  static let version = info("CFBundleShortVersionString")

  private static func info(_ key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
  }
}
