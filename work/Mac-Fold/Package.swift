// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacFold",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LidAngleKit",
            path: "Sources/LidAngleKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MacFold",
            dependencies: ["LidAngleKit"],
            path: "Sources/MacFold",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "lidprobe",
            dependencies: ["LidAngleKit"],
            path: "Sources/lidprobe",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
