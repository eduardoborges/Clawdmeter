// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Clawdmeter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClawdmeterCore"),
        .executableTarget(name: "Clawdmeter", dependencies: ["ClawdmeterCore"]),
        .testTarget(name: "ClawdmeterCoreTests", dependencies: ["ClawdmeterCore"]),
    ],
    // CoreBluetooth delegates and strict concurrency don't mix well yet.
    swiftLanguageModes: [.v5]
)
