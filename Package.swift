// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VirtualDesktopBadge",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "VirtualDesktopBadgeCore"),
        .executableTarget(
            name: "virtualdesktopbadge",
            dependencies: ["VirtualDesktopBadgeCore"]
        ),
        .testTarget(
            name: "VirtualDesktopBadgeCoreTests",
            dependencies: ["VirtualDesktopBadgeCore"]
        ),
    ]
)
