// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Tally",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TallyCore"),
        .executableTarget(name: "Tally", dependencies: ["TallyCore"]),
        .testTarget(name: "TallyCoreTests", dependencies: ["TallyCore"]),
    ],
    // CoreBluetooth delegates and strict concurrency don't mix well yet.
    swiftLanguageModes: [.v5]
)
