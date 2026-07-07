// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DebugBridge",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DebugBridgeCore", targets: ["DebugBridgeCore"]),
        .library(name: "DebugBridgeUI", targets: ["DebugBridgeUI"]),
        .library(name: "DebugBridgeTouch", targets: ["DebugBridgeTouch"]),
        .library(name: "DebugBridgeGenerated", targets: ["DebugBridgeGenerated"]),
    ],
    targets: [
        .target(
            name: "DebugBridgeCore",
            dependencies: [],
            path: "Sources/DebugBridgeCore",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "DebugBridgeTouch",
            dependencies: [],
            path: "Sources/DebugBridgeTouch",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),
        .target(
            name: "DebugBridgeUI",
            dependencies: ["DebugBridgeCore", "DebugBridgeTouch"],
            path: "Sources/DebugBridgeUI",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "DebugBridgeGenerated",
            dependencies: ["DebugBridgeCore"],
            path: "DebugBridgeGenerated",
            exclude: [".gstack-version"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "DebugBridgeCoreTests",
            dependencies: ["DebugBridgeCore"],
            path: "Tests/DebugBridgeCoreTests"
        ),
    ]
)
