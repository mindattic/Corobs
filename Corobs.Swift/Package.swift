// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Corobs",
    products: [
        .library(name: "Corobs", targets: ["Corobs"]),
    ],
    targets: [
        .target(name: "Corobs"),
        .testTarget(name: "CorobsTests", dependencies: ["Corobs"]),
    ]
)
