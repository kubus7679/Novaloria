# Novaloria — Build & Run

Wichtige Befehle zum Starten und Debuggen der App.

## Voraussetzungen

- macOS 14+
- Xcode bzw. Swift Toolchain (SwiftPM)

Alle Befehle im Projekt-Root ausführen.

## Für Benutzer (schneller Start)

```bash
# App bauen und starten
swift run Novaloria
```

In der App kannst du:
- **Verbinden** zu einem laufenden FreeCol-Server nutzen oder
- **Neues Spiel erstellen…** mit einem echten lokalen Java-Server verwenden oder
- **Lokales Spiel** für einen lokalen Mock-Start verwenden.

### Neue Java-Partie erstellen

1. In der Startansicht oder Lobby **Neues Spiel erstellen…** öffnen.
2. Den FreeCol-Installationsordner mit `FreeCol.jar` und `data/` sowie das
   ausführbare Java-Programm wählen (passende Java-Version für diese Installation erforderlich).
3. **Optionen laden** liest alle Spiel-, Karten- und Schwierigkeitsoptionen
   einschließlich geerbter Definitionen aus dem `freecol`-Regelset der Installation.
   Nach Wahl einer Schwierigkeitsvorlage lassen sich deren Werte einzeln anpassen.
   Ein Vorlagenwechsel setzt bisherige Änderungen zurück. Einheitenlisten sind
   im erweiterten XML-Editor bearbeitbar; sonst gibt es Schalter, Auswahllisten
   und Eingabefelder mit Prüfung der Java-Wertebereiche.
4. Optional Servername, freien Port und Zufallsstartwert setzen.
   **Optionsdatei exportieren…** speichert die Konfiguration ohne Serverstart.
5. **Spiel erstellen** speichert eine eigene Partie unter
    `~/Library/Application Support/Novaloria/Games/<UUID>/`, startet Java und
   verbindet den Client. Anschließend wie gewohnt anmelden, **Bereit** wählen
   und als Administrator **Spiel starten** drücken.

Der Ordner enthält `game-options.xml`, `launch-arguments.json`, `server.log`
und `console.log`; er lässt sich aus der Startansicht im Finder öffnen.
Die Optionsdatei ist eine geerbte FreeCol-Spezifikation: Ein eigenes Regelset
bindet sie beim Java-Start über `--rules` ein. Die Java-Installation wird nicht
verändert. Übliche `game_options.xml`/`map_generator_options.xml` werden vom
headless Java-Server nicht automatisch beim Start übernommen.
Der Server lauscht privat auf `127.0.0.1`; LAN-/Docker-Hosting ist hier nicht
enthalten. Beim Trennen oder Beenden der App wird nur der von der App gestartete
Server beendet. Nicht gespeicherter Spielfortschritt geht dabei verloren.
Eine bestehende Lobby wird erst nach Bestätigung verlassen.

### Spielstand laden

1. In der Startansicht oder Lobby **Spielstand laden…** öffnen und eine `.fsg`-Datei wählen.
2. FreeCol-Installation und Java-Programm wie bei einer neuen Partie wählen; beide Angaben werden geteilt.
3. **Server mit Spielstand starten** kopiert den Spielstand in den Partieordner unter
   `~/Library/Application Support/Novaloria/Games/<UUID>/`, startet Java mit `--load-savegame`
   und verbindet den Client.
4. Anmelden mit dem exakten Namen eines menschlichen Spielers aus dem Spielstand. Optionen, Karte
   und Regeln kommen aus dem Spielstand; nach der Anmeldung läuft das Spiel direkt, ohne Lobby und ohne Startknopf.
   KI-Spieler lassen sich nicht anmelden.

Der Spielstand muss zur Version der gewählten Java-Installation passen.

Gezielter Integrationstest mit einer gebauten Java-Installation:

```bash
FREECOL_NEW_GAME_E2E_DIR=../freecol \
FREECOL_JAVA_BIN=/opt/homebrew/opt/openjdk/bin/java \
swift test --filter NewGameTests
```

Die Lobby zeigt nur unterstützte Änderungen: verfügbare Völker, die eigene
Spielerfarbe und den Bereitschaftsstatus. **Spiel starten** ist nur für den
Administrator sichtbar. Der Name ist nach der Anmeldung nicht mehr bearbeitbar.
Startgold lässt sich unter **Optionen für lokales Spiel** ausschließlich für den
Mock-Start einstellen; bei Serverpartien bestimmt der Server Gold, Karte und
Spielregeln anhand der beim Erstellen gewählten Konfiguration. Laufende
Serverpartien lassen sich darüber nicht nachträglich umkonfigurieren.
Der Lobby-Hintergrund ist die originale historische Karte aus FreeCol
(`data/base/resources/images/ui/map.jpg`, `image.flavor.Canvas.map`), gebündelt
als `lobby-background.jpg`; die FreeCol-Lizenz liegt den App-Ressourcen bei.

### Bedienung im Spiel

- **Einheit auswählen:** Linksklick auf die Einheit; wiederholtes Klicken wechselt
  durch die eigenen Einheiten auf diesem Feld.
  **Nächste/Vorherige Einheit** überspringt Kolonisten an Koloniearbeitsplätzen.
  Sie zählen nicht als „Einheiten ohne Befehl“ und lösen keine Zugende-Warnung aus;
  im Koloniedialog bleiben sie auswählbar.
- **Bewegen:** Einheit auswählen, **Bewegen…** drücken und anschließend das Ziel auf
  der Karte anklicken. **Abbrechen** oder Escape bricht die Zielwahl ab.
  Alternativ: Die ausgewählte Einheit per **Rechtsklick direkt zum Ziel schicken**.
  Sie folgt einem bekannten, passierbaren Pfad, bis das Ziel erreicht oder ihre
  Bewegung für diesen Zug aufgebraucht ist. Ein übriges Fernziel bleibt gespeichert;
  im nächsten eigenen Zug wird die Bewegung automatisch fortgesetzt.
  Die ausgewählte Einheit zeigt ihren Weg gelb gestrichelt und ihr Ziel markiert;
  die Kartenebene **Wege** zeigt die Marschbefehle aller eigenen Einheiten.
  Blockierte Wege melden einen Fehler und behalten das Ziel für den nächsten Zug.
  Zieländerungen und das Löschen von Marschbefehlen werden erst nach
  Serverbestätigung übernommen; während laufender Bewegung sind sie gesperrt.
  **Option + Rechtsklick** öffnet stattdessen das Feldmenü.
  Gerüchte verlorener Städte sind mit dem originalen Ruinensymbol markiert.
  Nach ihrer Erkundung verschwindet das Symbol mit dem Serverupdate.
  Rohstoffvorkommen zeigen ihre Originalgrafiken auf der Karte, im Koloniegelände
  und in der Feldinformation. Die Ressourcenebene ergänzt Namen und endliche Mengen.
- **Von Bord gehen:** Auf dem Schiff unter **Passagiere** die gewünschte Einheit
  auswählen. An der Küste ein benachbartes, begehbares Landfeld rechtsklicken
  oder **Von Bord gehen** drücken und anschließend das Landfeld anklicken.
  Auch Passagiere auf Wache können so anlanden; ohne eigene Bewegungspunkte
  müssen sie bis zum nächsten Zug warten. Das Schiff bleibt dabei auf seinem Feld.
  Im Hafen bzw. in Europa wird direkt ausgeladen, auch mit 0 Bewegungspunkten.
  In **Europa → Hafen und Fracht** gibt es dafür eine Schaltfläche je Passagier.
  Zum Einschiffen oben ein Schiff im Europahafen wählen und bei der Einheit
  unter **Docks** auf **An Bord** klicken. Freier Laderaum ist erforderlich;
  Bewegungspunkte sind beim Einschiffen am selben Ort nicht nötig.
- **Kolonie öffnen:** Doppelklick auf das Koloniefeld oder Feld auswählen und
  **Kolonie** bzw. **Kolonie öffnen** drücken. Das funktioniert auch mit ausgewählter
  Einheit und nach dem Schließen erneut.
  Die Bauauswahl zeigt deutsche Gebäudenamen mit den jeweiligen Baukosten.
  Einheitenbefehle sind typgerecht: Koloniearbeit nur für Personen,
  die Europa-Reise nur für Schiffe. Erstkontaktmeldungen zeigen Spielernamen
  statt interner IDs, ersatzweise den deutschen Volksnamen.
- **Europa:** Die Bereiche **Hafen und Fracht**, **Markt** sowie
  **Rekrutierung** (einschließlich Ausbildung) sind direkt anwählbar. Die Schiffsauswahl
  bleibt beim Bereichswechsel erhalten. **Schließen** oder Escape beendet den Dialog.
  Kostenpflichtige Rekrutierung berücksichtigt Gold und Einwanderungspunkte;
  kostenlose Auswanderung bleibt möglich. Unterwegs befindliche Schiffe zeigen
  Ziel und verbleibende Runden im Hafen und im Inspektor. Ihre Auswahl bleibt
  bei Serverupdates erhalten; die Ankunft wird mit Schiffsname gemeldet.
  **Nach Europa** ist nur auf einem vom Spiel vorgesehenen Hochsee-Ausfahrtsfeld
  am Kartenrand verfügbar, nicht im Hafen oder auf gewöhnlichen Meeresfeldern.
  Diese Ausfahrten tragen die originalen weißen Hochsee-Wolken; die Minikarte
  hebt sie dunkelblau hervor und die Feldinformation nennt die Europa-Ausfahrt.
  Für die Rückreise unter **Hafen und Fracht** ein Schiff wählen und
  **Zur Neuen Welt aufbrechen** drücken. Fracht und Passagiere reisen mit;
  die Überfahrt beginnt erst nach Serverbestätigung (Java-Server erforderlich).
  Docks, Passagierliste, Rekrutierung sowie Kauf und Ausbildung zeigen die
  passenden Einheitengrafiken, einschließlich Schiffen und Artillerie.
- **Handelsrouten:** Der Editor zeigt deutsche Haltepunkt-, Waren- und Aktionsnamen.
  Eine ausgewählte eigene Einheit mit Waren-Transportfähigkeit kann eine eigene
  Route erhalten; Kolonisten und reine Passagiertransporter sind ausgeschlossen.
  Zuweisung, Entfernen und Wechsel des aktuellen Halts werden erst nach
  Serverbestätigung übernommen. Ungültige Haltepunkte werden abgewiesen.
  Diese Befehle werden ohne Verbindung nicht zur späteren Wiederholung eingereiht.
- **Spiel speichern:** **Spiel → Spiel speichern…** oder **Cmd+S** exportiert
  einen vollständigen `.fsg`-Spielstand einschließlich KI und verdeckter Karte.
  Nur der Spieladministrator kann im eigenen Zug speichern; die lokale
  Mock-Partie unterstützt keine vollständigen Spielstände. Der Java-Server
  benötigt dafür die optionale Speichererweiterung:
  `bash Tools/install-save-extension.sh ../freecol`.
  Diese wird in die vorhandene `FreeCol.jar` eingebaut (nach einem Java-Neubau
  erneut installieren). Eine bereits laufende Java-Instanz bleibt unverändert:
  zuerst dort sichern, dann den Server mit dem gesicherten Spielstand neu starten.
  Ohne Erweiterung wird kein erfolgreicher Speichervorgang vorgetäuscht.
  Der Export ist auf 8 MiB begrenzt und wird atomar am gewählten Ort geschrieben.
  Laden erfolgt weiterhin über Java mit `--load-savegame "/Pfad/Spiel.fsg"`.
  Export und erneutes Laden gegen den erweiterten lokalen Java-Server testen:
  `LOCAL_FREECOL_DIR=../freecol JAVA_BIN=/opt/homebrew/opt/openjdk/bin/java RUN_SAVE_E2E=1 ONLY='save saveload' STRICT_SKIPS=1 bash Tools/e2e-java-server.sh`.
- **Diplomatie:** Angebote und Gegenangebote verwenden die Java-Spielerzuordnung;
  neue Antworten bleiben sichtbar. Frieden und ein 100-Gold-Geschenk sind gegen
  die echte Java-AI geprüft. Bewaffnete Landeinheiten und Artillerie können
  neben fremden europäischen Kolonien **Tribut verhandeln…** öffnen.
  Vorgeschlagen werden Frieden und 100 Gold vom Gegenüber; Beträge und Klauseln
  bleiben bearbeitbar. Die AI darf ablehnen. Echte Tribut-Annahme und Goldzuwachs
  sind mit einer militärisch überlegenen Testnation verifiziert.
- Abgelehnte Serveraktionen werden einheitlich auf Deutsch erklärt. Unbekannte
  Fehler behalten die technische Meldung. Bei Zeitüberschreitungen zuerst den
  Spielstand prüfen, bevor eine möglicherweise bereits ausgeführte Aktion wiederholt wird.
- **Kolonie:** Gelände und Versorgung, Gebäude mit Arbeiterplätzen, Bauauftrag und
  ausgewählter Arbeiter stehen gemeinsam in einem großen Fenster. Freie Einwohner,
  Hafen/Fracht und Lagerbilanz bleiben darunter erreichbar, ohne Bereichsreiter.
  Bei kleinen Fenstern scrollt die gemeinsame Ansicht; lange Gebäude- und Warenlisten
  scrollen innerhalb ihres Bereichs. Aktionen und Serverupdates behalten die geöffnete Kolonie bei.
  **Vorherige** und **Nächste** blättern alphabetisch durch die eigenen Kolonien
  (mit Umlauf); das Dropdown im Kolonienamen öffnet direkt eine bestimmte Kolonie.
  Ein Arbeiterporträt auswählen und ein Feld oder einen freien Gebäudeplatz anklicken.
  Alternativ Arbeiter auf ein Feld oder Gebäude ziehen; belegte Felder tauschen die Arbeiter.
  Warensymbole zeigen die Produktionsvorhersage der besetzten Felder und des Zentrums
  einschließlich bekannter Boni; unbesetzte Felder zeigen die möglichen Basiswerte.
  **Tooltips** erklären Grundwerte, Arbeiter-/Gelände-/Kolonieboni, verfügbare Rohstoffe,
  Rundung, Verbrauch und Bilanz. Die Gebäude- und Feldwerte verwenden dieselbe Berechnung
  wie die Produktionsübersicht. Vorhersagen sind als clientseitige Schätzungen
  gekennzeichnet; das endgültige Rundenergebnis berechnet der Server.
  Fremde Kolonien zeigen nur bekannte Daten und bleiben schreibgeschützt.
  Der Koloniebonus ist ein additiver Wert, kein Prozentwert.
  Weitere Tooltips erläutern Nahrung/Wachstum, Baumaterialien, Bauzeit und Frachtgrenzen.
  Das Kolonieland ist vergrößert; der Bauauftrag steht direkt unter Nahrung und Wachstum.
  Die Lehrerauswahl befindet sich im Rechtsklickmenü des ausgewählten Kolonisten;
  dessen verbleibende Ausbildungszeit wird im Arbeiter-Inspector angezeigt.
  Im Lager wird die maximale Kapazität je Warenart aus den gebauten Lagergebäuden angezeigt.
  Das Zentrum arbeitet automatisch, Wasser benötigt ein Dock. Fremdes Land wird
  nicht automatisch gekauft oder gestohlen. Gebäude bleiben über die Arbeitsplatz-
  auswahl erreichbar. **Bauliste…** und **Produktionsdetails…** öffnen Detail-Popover,
  **Export- und Importregeln…** die Lagereinstellungen.
  Der Name lässt sich unter **Verwaltung** per Schaltfläche
  oder Eingabetaste ändern; abgelehnte
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
- Siedlungsbeschriftungen zeigen Bevölkerung und Namen auf einem transparenten
  Schild in der Nationsfarbe. Eigene Kolonien zeigen darunter das aktuelle
  Bauvorhaben und die geschätzten Restzüge aus Vorräten und Nettoproduktion aller
  benötigten Waren; `?` bedeutet, dass die Fertigstellung nicht abschätzbar ist.
  Fremde Bauvorhaben bleiben verborgen. Beschriftungen beachten Sichtbarkeit
  und vermeiden Überlappungen; sie lassen sich im Ansichtsmenü ausblenden.
  Grenzen bilden abgerundete, zusammenhängende Außenkonturen pro Nation,
  ohne Trennlinien zwischen eigenen Nachbarfeldern.
- Das Spielfenster benötigt mindestens 900 × 620 Punkte. Bewegung setzt wie
  bisher den eigenen Zug und eine aktive Einheit mit Bewegungspunkten voraus;
  transportierte Einheiten müssen zuerst ausgeschifft werden.

## Für Entwickler

### UI-Ressourcen

Terrain-Basis, Wald-/Höhen-Overlays, Küstenvarianten, rollenspezifische
Einheitengrafiken, deutsche Objektnamen sowie Colopädie-Texte und -Grafiken werden
aus dem lokalen FreeCol-Checkout importiert:

```bash
python3 Tools/import-ui-resources.py ../freecol
```

Diese Ressourcen stammen von den FreeCol-Mitwirkenden
([FreeCol](https://www.freecol.org), GPL v2). Die Lizenz wird als
`Sources/Novaloria/Resources/FreeCol-COPYING` mitgeliefert.
Der Zähe Pionier nutzt mit Werkzeugen seine Pioniergrafik, ohne Werkzeuge die
Zivilgrafik.
Die Küsten verwenden die stilkodierten Edge-/Corner-Texturen des Originals;
die neuere animierte Java-Übergangsdarstellung wird nicht nachgebildet.
Straßen, Flüsse und Pflugspuren werden als vereinfachte Kartenoverlays gezeichnet.

### Build

```bash
# Nur App-Target bauen
swift build --target Novaloria

# Gesamtes Paket bauen
swift build
```

### Starten

```bash
# SwiftUI-App starten
swift run Novaloria

# Protokoll-/Integrations-CLI starten
swift run FreeColProtocolCLI
```

### Tests

```bash
# SwiftPM-Tests
swift test
```

### Java-Server-E2E

Validiert den Client gegen den echten Java-FreeCol-Server. Standardmäßig wird
Docker mit dem Image `docker-freecol-server:latest` aus `../freecol/docker`
verwendet. Alternativ genügt ein lokal gebauter Java-Checkout:

```bash
Tools/e2e-java-server.sh                            # alle Proben, Summary am Ende
ONLY="recruitment traderoute" Tools/e2e-java-server.sh  # einzelne Proben
STRICT_SKIPS=1 Tools/e2e-java-server.sh             # Skips (kein erreichbares Ziel) = Fehler
LOCAL_FREECOL_DIR=../freecol JAVA_BIN=/opt/homebrew/opt/openjdk/bin/java \
  STRICT_SKIPS=1 Tools/e2e-java-server.sh            # ohne Docker, eigener Port 3559
```

Die Summary trennt *passed*, *skipped* und *failed*. Eine geskippte Probe ist **nicht**
validiert. Der vollständige Lauf am 31. Oktober 2026 besteht alle 14 Proben ohne
Skip, einschließlich Frieden/Geschenk, Frieden/Tribut mit je 100 Gold und
Ausschiffen erschöpfter Passagiere in Europa. Die Gameplay-Probe bestätigt
außerdem die tatsächliche Küstenlandung vom Schiff auf ein Landfeld.
Im lokalen Modus erhält jede Probe eigene Konfigurations-/Datenverzeichnisse
und einen frischen Server, der beim Ende beendet wird. Ein belegter Testport wird
abgelehnt statt ein bestehender Server verwendet. `FREECOL_PORT` überschreibt
den Port; Logs bleiben im am Ende genannten temporären Verzeichnis.
`KEEP_SERVER=1` ist nur im Docker-Modus verfügbar.

Die deterministischen Spielstands-Fixtures lassen sich aus einem Java-Autosave
erzeugen:

```bash
python3 Tools/prepare-e2e-savegame.py /path/to/autosave.fsg Tools/fixtures/native-trade.fsg
python3 Tools/prepare-scenario-e2e.py Tools/fixtures/native-trade.fsg Tools/fixtures/scenario-e2e.fsg
python3 Tools/prepare-scenario-e2e.py Tools/fixtures/native-trade.fsg Tools/fixtures/tribute-e2e.fsg --tribute
python3 Tools/prepare-abandon-e2e.py Tools/fixtures/scenario-e2e.fsg Tools/fixtures/abandon-e2e.fsg
```

Die separate Tribut-Fixture ergänzt acht eigene Veteranen als Dragoner neben
der AI-Kolonie. Damit ist Frieden gegen eine Zahlung ein akzeptables Angebot für
die schwächere AI; unveränderte Vertragsklauseln, PEACE und exakt 100 Gold
Zuwachs werden geprüft. Die übrigen Szenario-Proben behalten ihre eigene Fixture.

### App-Bundle erzeugen

```bash
bash Tools/build-app.sh
```

## Debugging

### Laufzeit-Logs in der Konsole

Beim Start über `swift run Novaloria` siehst du Debug-Logs direkt im Terminal (z. B. gesendete/empfangene XML-Nachrichten).

### Protokollpfade schnell prüfen

```bash
# End-to-end Protokollpfade / Message-Checks
swift run FreeColProtocolCLI
```

### Typische Schleife für Änderungen

```bash
swift build --target Novaloria
swift test
swift run FreeColProtocolCLI
```

## Nützliche Projektpfade

- App: `Sources/Novaloria/`
- Client/Session: `Sources/NovaloriaClient/`
- Protokoll: `Sources/FreeColProtocol/`
- Spielmodell: `Sources/FreeColGame/`
- Tests: `Tests/`
- Build-Helfer: `Tools/build-app.sh`
