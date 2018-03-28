// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "TestFrontend",
    products: [
        .library(name: "TestFrontend", targets: ["TestFrontend"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "TestFrontend", dependencies: []),
    ]
)
