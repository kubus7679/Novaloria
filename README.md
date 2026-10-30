# FreeColClient (macOS SwiftUI)

Wichtige Befehle zum Starten und Debuggen der App.

## Voraussetzungen

- macOS 14+
- Xcode bzw. Swift Toolchain (SwiftPM)

Alle Befehle im Projekt-Root ausführen.

## Für Benutzer (schneller Start)

```bash
# App bauen und starten
swift run FreeColApp
```

In der App kannst du:
- **Connect** zu einem laufenden FreeCol-Server nutzen oder
- **Local Game** für einen lokalen Mock-Start verwenden.

## Für Entwickler

### Build

```bash
# Nur App-Target bauen
swift build --target FreeColApp

# Gesamtes Paket bauen
swift build
```

### Starten

```bash
# SwiftUI-App starten
swift run FreeColApp

# Protokoll-/Integrations-CLI starten
swift run FreeColProtocolCLI
```

### Tests

```bash
# SwiftPM-Tests
swift test
```

### Java-Server-E2E

Validiert den Client gegen den echten Java-FreeCol-Server (Docker nötig, Image
`docker-freecol-server:latest` aus `../freecol/docker`).

```bash
Tools/e2e-java-server.sh                            # alle Proben, Summary am Ende
ONLY="recruitment traderoute" Tools/e2e-java-server.sh  # einzelne Proben
STRICT_SKIPS=1 Tools/e2e-java-server.sh             # Skips (kein erreichbares Ziel) = Fehler
```

Die Summary trennt *passed*, *skipped* und *failed*. Eine geskippte Probe ist **nicht**
validiert. Aktueller Stand: siehe `Docs/Plans/next-phases-plan.md`.

Die deterministischen Spielstands-Fixtures lassen sich aus einem Java-Autosave
erzeugen:

```bash
python3 Tools/prepare-e2e-savegame.py /path/to/autosave.fsg Tools/fixtures/native-trade.fsg
python3 Tools/prepare-scenario-e2e.py Tools/fixtures/native-trade.fsg Tools/fixtures/scenario-e2e.fsg
```

### App-Bundle erzeugen

```bash
Tools/build-app.sh
```

## Debugging

### Laufzeit-Logs in der Konsole

Beim Start über `swift run FreeColApp` siehst du Debug-Logs direkt im Terminal (z. B. gesendete/empfangene XML-Nachrichten).

### Protokollpfade schnell prüfen

```bash
# End-to-end Protokollpfade / Message-Checks
swift run FreeColProtocolCLI
```

### Typische Schleife für Änderungen

```bash
swift build --target FreeColApp
swift test
swift run FreeColProtocolCLI
```

## Nützliche Projektpfade

- App: `Sources/FreeColApp/`
- Client/Session: `Sources/FreeColClient/`
- Protokoll: `Sources/FreeColProtocol/`
- Spielmodell: `Sources/FreeColGame/`
- Tests: `Tests/`
- Build-Helfer: `Tools/build-app.sh`
