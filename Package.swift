// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scrubbers",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "Scrubbers", targets: ["Scrubbers"]),
    ],
    targets: [
        .target(name: "Scrubbers"),
        .testTarget(name: "ScrubbersTests", dependencies: ["Scrubbers"]),
    ]
)
