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
        .package(url: "https://github.com/steventong/SwiftHttpClient", revision: "d51f861f8076a805e5ba7474926a17039aeccc21")
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
            ],
            swiftSettings: [
                // 异步方法默认在调用方所在线程执行，App 在主线程调用时不用跨线程传递非并发安全的客户端对象。
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "SynologySwiftKitTests",
            dependencies: ["SynologySwiftKit"],
            swiftSettings: [
                // 与主 target 保持一致，测试替身才能匹配协议里的异步闭包签名。
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]),
    ]
)
