# FreeColClient — Agent Instructions

A native macOS SwiftUI client for [FreeCol](https://www.freecol.org), a turn-based strategy game. Connects via TCP/XML to a Java FreeCol server.

## Build & Test

```bash
swift build --target FreeColApp    # build the app
swift run FreeColApp               # run the SwiftUI app
swift run FreeColProtocolCLI       # run the CLI protocol-debug tool
swift test                         # run all tests
Tools/build-app.sh                 # build & create .app bundle
docker compose -f docker/docker-compose.yml up  # start local FreeCol Java server (port 3541)
```

Requirements: macOS 14.0+, Xcode / Swift toolchain.

## Module Map

| Module | Role |
|--------|------|
| `FreeColProtocol` | TCP connection, XML wire protocol, 150+ message types, handshake |
| `FreeColGame` | Game data model (`Game`, `Player`, `Tile`, `Unit`, `Colony`), XML deserialization |
| `FreeColClient` | High-level `FreeColClient` actor — orchestrates connect/login/message loop |
| `FreeColApp` | SwiftUI views (`LoginView`, `GameView`, `MapView`), `GameState` observable |
| `FreeColProtocolCLI` | CLI tool for protocol debugging |

See [Docs/plans.md](Docs/plans.md) and [Docs/protocol.md](Docs/protocol.md) for design docs.

## Wire Protocol Conventions

- Plain TCP on port 3541, UTF-8, **newline-terminated** (`\n`) single-line XML
- No TLS, no pretty-printing. Example: `<buildColony unit="u1" name="Boston"/>\n`
- Attributes are **sorted alphabetically** by `XMLEncoder` for deterministic output
- Self-closing tags for empty elements: `<endTurn/>`

## Message Type Conventions

Every message is a Swift struct implementing `FreeColMessage`. Three categories:

1. **TrivialMessage** — tag only, no attributes (e.g., `EndTurnMessage`)
2. **AttributeMessage** — tag + key=value attributes (e.g., `BuildColonyMessage`)
3. **ObjectMessage** — tag + attributes + child elements (e.g., `LoginMessage`)

Pattern:
```swift
public struct BuildColonyMessage: FreeColMessage {
    public static let tag = "buildColony"   // Java TAG constant → camelCase
    public let unit: String?
    public let name: String?
    public init(unit: String? = nil, name: String? = nil) { … }
    public init(attributes: Attributes, children: Children) throws { … }
    public func encode() -> (attributes: Attributes, children: Children) { … }
}
```

- All model attributes are `String?`; use `attributes["key"]` / `attributes.int("key")`
- Java class `FooBarMessage` → XML tag `<fooBar>` (from the Java `TAG` constant)
- Swift reserved words in attribute names are wrapped with backticks by codegen

Examples: [Sources/FreeColProtocol/Messages/](Sources/FreeColProtocol/Messages/)

## Code Generation

Message files are **generated** from the Java FreeCol source:

```bash
python3 Tools/codegen.py <path-to-freecol-src> Sources/FreeColProtocol/Messages/
```

- Do **not** hand-edit generated files unless fixing a generation bug
- After regenerating, verify the `MessageRegistry` in [Sources/FreeColProtocol/](Sources/FreeColProtocol/) maps all new tags

## Key Pitfalls

- **MockServer** only handles login; action messages (movement, build, etc.) are not yet processed
- **`@unchecked Sendable`** — game model types must be marked for actor safety across module boundaries
- **GameStateManager** processes updates sequentially; out-of-order server messages can cause inconsistencies
- Always check `String?` attributes before use — missing XML attributes are nil, not empty strings
- Typos in `static let tag` break deserialization silently (message falls through to unknown-message handler)
