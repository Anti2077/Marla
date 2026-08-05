// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Marla",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MarlaCore", targets: ["MarlaCore"]),
        .executable(name: "Marla", targets: ["MarlaApp"])
    ],
    targets: [
        .target(
            name: "MarlaRustFFI",
            path: "Sources/MarlaRustFFI",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags(["-L", "target/debug"]),
                .linkedLibrary("marla_core")
            ]
        ),
        .target(
            name: "MarlaCore",
            dependencies: ["MarlaRustFFI"],
            path: "Sources/MarlaCore"
        ),
        .executableTarget(
            name: "MarlaApp",
            dependencies: ["MarlaCore"],
            path: "Sources/MarlaApp"
        ),
        .testTarget(
            name: "MarlaCoreTests",
            dependencies: ["MarlaCore"],
            path: "Tests/MarlaCoreTests"
        )
    ]
)
