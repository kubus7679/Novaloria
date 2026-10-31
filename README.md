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

### Bedienung im Spiel

- **Einheit auswählen:** Linksklick auf die Einheit; wiederholtes Klicken wechselt
  durch die eigenen Einheiten auf diesem Feld.
- **Bewegen:** Einheit auswählen, **Bewegen…** drücken und anschließend das Ziel auf
  der Karte anklicken. **Abbrechen** oder Escape bricht die Zielwahl ab.
  Alternativ: Die ausgewählte Einheit per **Rechtsklick direkt zum Ziel schicken**.
  Sie folgt einem bekannten, passierbaren Pfad, bis das Ziel erreicht oder ihre
  Bewegung für diesen Zug aufgebraucht ist. Ein übriges Fernziel bleibt gespeichert;
  die Fortsetzung im nächsten Zug erfolgt derzeit durch erneuten Rechtsklick.
  **Option + Rechtsklick** öffnet stattdessen das Feldmenü.
- **Kolonie öffnen:** Doppelklick auf das Koloniefeld oder Feld auswählen und
  **Kolonie** bzw. **Kolonie öffnen** drücken. Das funktioniert auch mit ausgewählter
  Einheit und nach dem Schließen erneut.
- **Europa:** Die Bereiche **Hafen und Fracht**, **Markt** sowie
  **Rekrutierung** (einschließlich Ausbildung) sind direkt anwählbar. Die Schiffsauswahl
  bleibt beim Bereichswechsel erhalten. **Schließen** oder Escape beendet den Dialog.
  Kostenpflichtige Rekrutierung berücksichtigt Gold und Einwanderungspunkte;
  kostenlose Auswanderung bleibt möglich.
- **Kolonie:** Übersicht, Arbeiter/Felder, Gebäude/Bau und Lager/Fracht sind
  getrennte Bereiche. Unter **Arbeiter und Felder** einen Arbeiter auswählen und
  ein Feld der Geländeübersicht anklicken; belegte Felder tauschen die Arbeiter.
  Das Zentrum arbeitet automatisch, Wasser benötigt ein Dock. Fremdes Land wird
  nicht automatisch gekauft oder gestohlen. Gebäude bleiben über die Arbeitsplatz-
  auswahl erreichbar. Der Name lässt sich unter **Übersicht** ändern; abgelehnte
  Serveraktionen werden im Dialog angezeigt.
  **Verwaltung** enthält das bestätigungspflichtige Verlassen der Kolonie.
- **Colopädie:** Deutsche Suche und Kategorieauswahl führen zu 206 Einträgen des
  klassischen Regelwerks, mit Originalgrafiken, Beschreibungen, Spielwerten und
  anklickbaren verwandten Einträgen. Verfügbare Werte kommen aus der
  Serverspezifikation; die Beschreibungen bleiben dem klassischen Regelwerk zugeordnet.
- Ausrüstungs- und Verbesserungsaktionen berücksichtigen Einheit und Standort.
  Schiffe und Wagen werden beispielsweise nicht als Missionare oder Pioniere angeboten.
- Der rechte Inspektor bündelt Porträt, Bewegungspunkte, Befehle und Fracht.
  **Befehle** enthält unter anderem Wache, Befestigen und Auflösen.
  Das kompakte untere HUD bietet Minimap, **Zugbericht**, Einheitenauswahl und
  **Zug beenden**. Menüs und Einheitenaktionen bleiben scrollbar.
- Die Kamera behält beim Vergrößern/Verkleinern des Fensters ihren Mittelpunkt,
  soweit die Kartengrenzen es erlauben. **Ansicht → Auswahl zentrieren** führt
  zur ausgewählten Einheit bzw. zum Feld zurück.
- Das Spielfenster benötigt mindestens 900 × 620 Punkte. Bewegung setzt wie
  bisher den eigenen Zug und eine aktive Einheit mit Bewegungspunkten voraus;
  transportierte Einheiten müssen zuerst ausgeschifft werden.

## Für Entwickler

### UI-Ressourcen

Terrain-Basis, Wald-/Höhen-Overlays, Küstenvarianten, deutsche Objektnamen sowie
Colopädie-Texte und -Grafiken werden aus dem lokalen FreeCol-Checkout importiert:

```bash
python3 Tools/import-ui-resources.py ../freecol
```

Diese Ressourcen stammen von den FreeCol-Mitwirkenden
([FreeCol](https://www.freecol.org), GPL v2). Die Lizenz wird als
`Sources/FreeColApp/Resources/FreeCol-COPYING` mitgeliefert.
Die Küsten verwenden die stilkodierten Edge-/Corner-Texturen des Originals;
die neuere animierte Java-Übergangsdarstellung wird nicht nachgebildet.
Straßen, Flüsse und Pflugspuren werden als vereinfachte Kartenoverlays gezeichnet.

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
python3 Tools/prepare-abandon-e2e.py Tools/fixtures/scenario-e2e.fsg Tools/fixtures/abandon-e2e.fsg
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
