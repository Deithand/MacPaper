// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPaper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacPaper", targets: ["MacPaper"])
    ],
    targets: [
        .executableTarget(
            name: "MacPaper",
            path: "Sources/MacPaper",
            resources: [.process("Resources")]
        )
    ]
)
