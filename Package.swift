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
                .copy("Resources/object-names-de.json"),
                .copy("Resources/colopedia-de.json"),
                .copy("Resources/colopedia"),
                .copy("Resources/FreeCol-COPYING"),
                .copy("Resources/lobby-background.jpg"),
                .copy("Resources/freecol-app-icon.svg"),
            ]
        ),
        .testTarget(
            name: "FreeColProtocolTests",
            dependencies: ["FreeColProtocol", "FreeColGame", "FreeColApp"]
        ),
    ]
)
