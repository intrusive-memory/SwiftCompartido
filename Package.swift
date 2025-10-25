// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCompartido",
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26)
    ],
    products: [
        .library(
            name: "SwiftCompartido",
            targets: ["SwiftCompartido"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mcritz/TextBundle.git", from: "1.0.0"),
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftCompartido",
            dependencies: [
                .product(name: "TextBundle", package: "TextBundle")
            ]
        ),
        .testTarget(
            name: "SwiftCompartidoTests",
            dependencies: [
                "SwiftCompartido",
                .product(name: "SwiftFijos", package: "SwiftFijos")
            ],
            resources: [
                .copy("../../Fixtures")
            ]
        ),
    ]
)
