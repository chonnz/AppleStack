// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleStack",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "AppleStack", targets: ["AppleStack"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AppleStack",
            dependencies: []
        ),
        .testTarget(
            name: "AppleStackTests",
            dependencies: ["AppleStack"]
        )
    ]
)
