// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SynologySwiftKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SynologySwiftKit",
            targets: ["SynologySwiftKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/steventong/SwiftHttpClient", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SynologySwiftKit",
            dependencies: [
                .product(name: "SwiftHttpClient", package: "SwiftHttpClient")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SynologySwiftKitTests",
            dependencies: ["SynologySwiftKit"]),
    ]
)
