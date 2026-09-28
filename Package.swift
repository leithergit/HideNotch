// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HideNotch",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "HideNotchCore", resources: [.process("Resources")]),
        .executableTarget(name: "HideNotch", dependencies: ["HideNotchCore"]),
        .executableTarget(name: "IconGen", dependencies: ["HideNotchCore"]),
        .testTarget(name: "HideNotchTests", dependencies: ["HideNotchCore"]),
    ]
)
