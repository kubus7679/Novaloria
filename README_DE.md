# Novaloria (Deutsch)

**Novaloria** ist ein nativer macOS-Client in SwiftUI für das rundenbasierte Strategiespiel [FreeCol](https://www.freecol.org). Er verbindet sich über das FreeCol-TCP/XML-Protokoll mit einem Java-FreeCol-Server.

> **Sprache:** Die Oberfläche ist auf Deutsch, Englisch und Spanisch lokalisiert. Wähle die Sprache auf dem Startbildschirm oder in den Spieleinstellungen oder folge der macOS-Systemsprache (nicht unterstützte Systemspracheinstellungen verwenden Englisch).

Die englische README findest du unter [README.md](README.md).

Novaloria ist ein unabhängiges Community-Projekt und steht in keiner offiziellen Verbindung zum FreeCol-Projekt.

## Funktionen

- Verbindung zu einem laufenden FreeCol-Server
- Lokale Java-Partien erstellen und Spielstände laden
- Karte, Kolonien, Europa, Diplomatie und Handelsrouten in einer nativen macOS-Oberfläche
- Spielstände über den Java-Server speichern (mit optionaler Server-Erweiterung)
- Swift-Protokoll-CLI für Protokolltests und Diagnose

Die Details und bekannten Einschränkungen sind in der [Build- und Bedienungsanleitung](Docs/build_and_run.md) beschrieben.

## Voraussetzungen

- macOS 14 oder neuer
- Xcode beziehungsweise Swift 5.9 oder neuer
- Für lokale Java-Partien: eine passende FreeCol-Installation und Java-Version

Zum Verbinden mit einem Server ist keine lokale Java-Installation erforderlich.

## Bauen und starten

```bash
swift build --target Novaloria
swift run Novaloria
```

Ein macOS-App-Bundle lässt sich mit folgendem Skript erzeugen:

```bash
bash Tools/build-app.sh
```

Weitere Hinweise zu Spielstart, Bedienung, Tests und Java-Server-Integration stehen in [`Docs/build_and_run.md`](Docs/build_and_run.md).

## Tests

```bash
swift test
```

Einige Java-Server-End-to-End-Tests benötigen zusätzlich eine lokal gebaute FreeCol-Installation oder Docker. Sie sind in der Build- und Bedienungsanleitung dokumentiert.

## Lizenz und Herkunft von Ressourcen

Der Quellcode dieses Projekts wird unter der **GNU General Public License, Version 2 only (GPL-2.0-only)** veröffentlicht. Siehe [`LICENSE`](LICENSE).

Das Repository enthält außerdem Grafiken und aus FreeCol-Daten abgeleitete Inhalte. Deren Herkunft und Lizenzhinweise stehen in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md); die mitgelieferte FreeCol-Lizenz befindet sich zusätzlich unter `Sources/Novaloria/Resources/FreeCol-COPYING`.
