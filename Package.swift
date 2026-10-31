// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Coast",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure math with no AppKit, so it can be unit tested without an event tap.
        .target(name: "CoastCore"),
        .executableTarget(name: "Coast", dependencies: ["CoastCore"]),
        .testTarget(name: "CoastCoreTests", dependencies: ["CoastCore"]),
    ]
)
