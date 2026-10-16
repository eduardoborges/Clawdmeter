// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Claudio",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClaudioCore"),
        .executableTarget(name: "Claudio", dependencies: ["ClaudioCore"]),
        .testTarget(name: "ClaudioCoreTests", dependencies: ["ClaudioCore"]),
    ],
    // CoreBluetooth delegates and strict concurrency don't mix well yet.
    swiftLanguageModes: [.v5]
)
