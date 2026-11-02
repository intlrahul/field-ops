// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prism",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Prism", targets: ["Prism"])],
    targets: [
        .target(name: "Prism", resources: [.process("Resources")])
    ]
)
