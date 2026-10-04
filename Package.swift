// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Connect4x4",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ConnectCore", targets: ["ConnectCore"]),
        .library(name: "ConnectUI", targets: ["ConnectUI"]),
        .executable(name: "connect-preview", targets: ["ConnectPreview"])
    ],
    targets: [
        .target(name: "ConnectCore"),
        .target(name: "ConnectUI", dependencies: ["ConnectCore"]),
        .executableTarget(name: "ConnectPreview", dependencies: ["ConnectUI", "ConnectCore"]),
        .testTarget(name: "ConnectCoreTests", dependencies: ["ConnectCore"])
    ]
)
