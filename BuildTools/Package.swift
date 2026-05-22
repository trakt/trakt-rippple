// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.61.1")
    ],
    targets: [
        .target(name: "BuildTools", path: "")
    ]
)
