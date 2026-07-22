// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OBSStopwatchMac",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "OBSStopwatchMac"
        ),
        .testTarget(
            name: "OBSStopwatchMacTests",
            dependencies: ["OBSStopwatchMac"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
