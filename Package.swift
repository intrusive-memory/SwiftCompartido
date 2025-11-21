// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCompartido",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SwiftCompartido",
            targets: ["SwiftCompartido"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mcritz/TextBundle.git", from: "1.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/ibrahimcetin/SwiftGitX.git", from: "0.1.9")
    ],
    targets: [
        .target(
            name: "SwiftCompartido",
            dependencies: [
                .product(name: "TextBundle", package: "TextBundle"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftGitX", package: "SwiftGitX")
            ]
        ),
        .testTarget(
            name: "SwiftCompartidoTests",
            dependencies: [
                "SwiftCompartido",
                .product(name: "SwiftFijos", package: "SwiftFijos")
            ],
            path: "Tests/SwiftCompartidoTests",
            resources: [
                .copy("../../Fixtures")
            ]
        ),
    ]
)
