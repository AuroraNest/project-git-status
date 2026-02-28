// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitRepoManager",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "GitRepoManager",
            path: "GitRepoManager"
        )
    ]
)
