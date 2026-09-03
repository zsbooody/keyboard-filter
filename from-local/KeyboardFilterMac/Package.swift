// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "KeyboardFilterMac",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "KeyboardFilterMac", targets: ["KeyboardFilterMac"])
    ],
    targets: [
        .executableTarget(
            name: "KeyboardFilterMac",
            path: "Sources"
        )
    ]
)