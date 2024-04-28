// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SynologySwiftKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SynologySwiftKit",
            targets: ["SynologySwiftKit"]),
    ],
    dependencies: [
       .package(
        url: "https://github.com/Alamofire/Alamofire.git",
        .upToNextMajor(from: "5.9.0")
       )
     ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SynologySwiftKit",
            dependencies: [
                .product(name: "Alamofire",
                          package: "Alamofire")
            ]
        ),
        .testTarget(
            name: "SynologySwiftKitTests",
            dependencies: ["SynologySwiftKit"]),
    ]
)
