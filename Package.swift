// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HideNotch",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "HideNotchCore"),
        .executableTarget(name: "HideNotch", dependencies: ["HideNotchCore"]),
        .testTarget(name: "HideNotchTests", dependencies: ["HideNotchCore"]),
    ]
)
