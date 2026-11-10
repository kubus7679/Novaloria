# Novaloria

**Novaloria** is a native macOS client built with SwiftUI for [FreeCol](https://www.freecol.org), the turn-based strategy game. It connects to a Java FreeCol server over the FreeCol TCP/XML protocol.

> **Language:** The interface is localized in German, English and Spanish. Choose a language on the startup screen or in-game preferences, or follow macOS's system language (unsupported system languages fall back to English).

Novaloria is an independent community project and is not officially affiliated with the FreeCol project.

## Features

- Connect to a running FreeCol server
- Create local Java games and load savegames
- Explore the map, colonies, Europe, diplomacy and trade routes in a native macOS interface
- Save games through the Java server (with an optional server extension)
- Swift protocol CLI for protocol testing and diagnostics

See the [build and operation guide](Docs/build_and_run.md) for details and known limitations (currently available in German). The German README is [README_DE.md](README_DE.md).

## Requirements

- macOS 14 or later
- Xcode or Swift 5.9 or later
- For local Java games: a compatible FreeCol installation and Java version

A local Java installation is not required to connect to a server.

## Build and run

```bash
swift build --target Novaloria
swift run Novaloria
```

Create a macOS app bundle with:

```bash
bash Tools/build-app.sh
```

For game setup, controls, tests and Java server integration, see [`Docs/build_and_run.md`](Docs/build_and_run.md).

## Tests

```bash
swift test
```

Some Java server end-to-end tests additionally require a local FreeCol installation or Docker. See the build and operation guide.

## License and resource attributions

The source code is distributed under the **GNU General Public License, version 2 only (GPL-2.0-only)**. See [`LICENSE`](LICENSE).

The repository also contains graphics and content derived from FreeCol data. Their origins and license notices are listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md); the included FreeCol license is also available at `Sources/Novaloria/Resources/FreeCol-COPYING`.
