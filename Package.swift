// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
//
// When this manifest is evaluated as a transitive dependency inside Xcode's
// `SourcePackages/checkouts/` or SwiftPM's `.build/checkouts/`, every other
// dependency lives as a sibling in the same directory. Treating those as
// in-development local paths produces conflicting package identities, so we
// must skip the sibling shortcut in that context.
let manifestDir = (#filePath as NSString).deletingLastPathComponent
let isSPMCheckout =
  manifestDir.contains("/SourcePackages/checkouts/")
  || manifestDir.contains("/.build/checkouts/")
let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
let useLocalSiblings = !isCI && !isSPMCheckout

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

/// Same sibling-priority pattern as ``sibling(_:remote:from:)`` but pins to a
/// remote branch when no local sibling exists. Use only when a temporary
/// pre-release dependency on a feature branch is required; switch back to the
/// version-pinned ``sibling(_:remote:from:)`` once the upstream tags a release.
func sibling(_ name: String, remote: String, branch: String) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, branch: branch)
}

let package = Package(
  name: "SwiftCompartido",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(
      name: "SwiftCompartido",
      targets: ["SwiftCompartido"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/mcritz/TextBundle.git", from: "1.0.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
    sibling(
      "SwiftFijos",
      remote: "https://github.com/intrusive-memory/SwiftFijos.git",
      from: "1.4.1"),
    sibling(
      "glosa-av",
      remote: "https://github.com/intrusive-memory/glosa-av.git",
      from: "0.7.1"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.0"),
  ],
  targets: [
    .target(
      name: "SwiftCompartido",
      dependencies: [
        .product(name: "TextBundle", package: "TextBundle"),
        .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "GlosaCore", package: "glosa-av"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftCompartidoTests",
      dependencies: [
        "SwiftCompartido",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
      ],
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftCompartidoPDFTests",
      dependencies: [
        "SwiftCompartido",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftCompartidoPerformanceTests",
      dependencies: [
        "SwiftCompartido",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ]
)
