// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WubiMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WubiEngine", targets: ["WubiEngine"]),
        .library(name: "WubiSupport", targets: ["WubiSupport"])
    ],
    targets: [
        .target(
            name: "WubiEngine",
            path: "WubiEngine/Sources",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "WubiSupport",
            dependencies: ["WubiEngine"],
            path: "WubiSupport/Sources"
        ),
        .testTarget(
            name: "WubiMacTests",
            dependencies: ["WubiEngine", "WubiSupport"],
            path: "WubiMacTests/Sources"
        )
    ]
)
