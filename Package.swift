// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "heemac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Heemac",
            path: "Sources/Heemac",
            linkerSettings: [
                // SkyLight provides the window-server calls used to focus a specific window.
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"]),
            ]
        ),
        .testTarget(name: "HeemacTests", dependencies: ["Heemac"]),
    ],
    swiftLanguageModes: [.v6]
)
