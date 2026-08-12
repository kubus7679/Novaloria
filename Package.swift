// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeColClient",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FreeColProtocol", targets: ["FreeColProtocol"]),
        .library(name: "FreeColGame", targets: ["FreeColGame"]),
        .library(name: "FreeColClient", targets: ["FreeColClient"]),
    ],
    targets: [
        .target(name: "FreeColProtocol"),
        .target(name: "FreeColGame", dependencies: ["FreeColProtocol"]),
        .target(name: "FreeColClient", dependencies: ["FreeColGame", "FreeColProtocol"]),
        .executableTarget(name: "FreeColProtocolCLI", dependencies: ["FreeColProtocol", "FreeColGame", "FreeColClient"]),
        .executableTarget(
            name: "FreeColApp",
            dependencies: ["FreeColProtocol", "FreeColGame", "FreeColClient"],
            resources: [
                .copy("Resources/terrain"),
                .copy("Resources/units"),
                .copy("Resources/settlements"),
                .copy("Resources/order-buttons"),
            ]
        ),
        .testTarget(name: "FreeColProtocolTests", dependencies: ["FreeColProtocol"]),
    ]
)
