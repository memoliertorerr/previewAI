// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PreviewAI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PreviewAI", targets: ["PreviewAI"]),
        .library(name: "PreviewAICore", targets: ["PreviewAICore"]),
    ],
    targets: [
        .target(name: "PreviewAICore"),
        .executableTarget(
            name: "PreviewAI",
            dependencies: ["PreviewAICore"]
        ),
        .testTarget(
            name: "PreviewAICoreTests",
            dependencies: ["PreviewAICore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
