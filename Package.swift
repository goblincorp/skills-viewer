// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkillsViewer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SkillsViewer",
            path: "Sources"
        )
    ]
)
