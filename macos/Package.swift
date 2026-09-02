// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "KeyboardFilter",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "KeyboardFilter",
            path: "Sources"
        )
    ]
)
