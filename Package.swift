// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskBadge",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DeskBadgeCore"),
        .executableTarget(
            name: "deskbadge",
            dependencies: ["DeskBadgeCore"]
        ),
        .testTarget(
            name: "DeskBadgeCoreTests",
            dependencies: ["DeskBadgeCore"]
        ),
    ]
)
