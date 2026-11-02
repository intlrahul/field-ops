// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PathRouter",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PathRouter", targets: ["PathRouter"]),
        .library(name: "PathRouterUI", targets: ["PathRouterUI"])
    ],
    targets: [
        .target(name: "PathRouter"),
        .target(name: "PathRouterUI", dependencies: ["PathRouter"]),
        .testTarget(name: "PathRouterTests", dependencies: ["PathRouter"])
    ]
)
