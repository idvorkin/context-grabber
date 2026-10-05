// swift-tools-version: 6.0
import PackageDescription

// The platform-free half of the native app: everything here runs under `swift test` on the Mac (docs/TESTING.md).
let package = Package(
  name: "ContextCore",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ContextCore", targets: ["ContextCore"])
  ],
  targets: [
    .target(name: "ContextCore"),
    .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"]),
  ],
  swiftLanguageModes: [.v5]
)
