// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Novaloria",
    defaultLocalization: "de",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FreeColProtocol", targets: ["FreeColProtocol"]),
        .library(name: "FreeColGame", targets: ["FreeColGame"]),
        .library(name: "NovaloriaClient", targets: ["NovaloriaClient"]),
    ],
    targets: [
        .target(name: "FreeColProtocol"),
        .target(name: "FreeColGame", dependencies: ["FreeColProtocol"]),
        .target(name: "NovaloriaClient", dependencies: ["FreeColGame", "FreeColProtocol"]),
        .executableTarget(name: "FreeColProtocolCLI", dependencies: ["FreeColProtocol", "FreeColGame", "NovaloriaClient"]),
        .executableTarget(
            name: "Novaloria",
            dependencies: ["FreeColProtocol", "FreeColGame", "NovaloriaClient"],
            exclude: ["Resources/freecol_background.jpg"],
            resources: [
                .copy("Resources/de.lproj"),
                .copy("Resources/en.lproj"),
                .copy("Resources/es.lproj"),
                .copy("Resources/NovaloriaLocalization-de.bundle"),
                .copy("Resources/NovaloriaLocalization-en.bundle"),
                .copy("Resources/NovaloriaLocalization-es.bundle"),
                .copy("Resources/terrain"),
                .copy("Resources/rivers"),
                .copy("Resources/units"),
                .copy("Resources/settlements"),
                .copy("Resources/order-buttons"),
                .copy("Resources/object-names-de.json"),
                .copy("Resources/model-message-texts-de.json"),
                .copy("Resources/colopedia-de.json"),
                .copy("Resources/colopedia"),
                .copy("Resources/FreeCol-COPYING"),
                .copy("Resources/lobby-background.jpg"),
                .copy("Resources/novaloria-app-icon.svg"),
            ]
        ),
        .testTarget(
            name: "FreeColProtocolTests",
            dependencies: ["FreeColProtocol", "FreeColGame", "Novaloria"]
        ),
    ]
)
