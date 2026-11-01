# Nächste Phasen — Planung

> **Stand:** 31. Oktober 2026
> **Fortschritt:** Phasen 105–108 sind implementiert und geprüft. Phase 93 hat jetzt native
> Layout-Prüfungen für Überfahrt, Ankunft und Europa-Kaufliste sowie stabile
> Auswahl über Modellupdates. Phase 95 bestätigt Frieden/Geschenk und
> Frieden/Tribut mit je exakt 100 Gold gegen den echten Java-Server.
> Die vollständige Java-Matrix besteht: **14 bestanden, 0 übersprungen,
> 0 fehlgeschlagen** mit `STRICT_SKIPS=1` im isolierten lokalen Java-Modus.
> **Grundsatz:** Neue Features erst auf real verifizierter Basis. Ein Probe-Lauf, der
> nur über den Skip-Pfad läuft, zählt nicht als Validierung.

## Aktueller Gesamtlauf `Tools/e2e-java-server.sh` (14 Proben)

| Status | Proben |
|--------|--------|
| Grün, ohne Skip | smoke, deep, gameplay, reject, traderoute, multiplayer, nativetrade, abandon, disembark, diplomacy, tribute, combat, missionaryspy, recruitment |
| Übersprungen | – |
| Rot | – |

Der erste Lauf hat drei echte Client-Fehler und mehrere falsche Probe-Annahmen
aufgedeckt (Details in `plans.md`, Phase 91). Daraus folgt: **Jede weitere
Funktion, die nur gegen den Mock-Server oder gar nicht geprüft wurde, ist verdächtig.**

---

## Cluster A — Validierung abschließen (Hoch)

### Phase 92 — Deterministische Fixtures für Native/Diplomatie/Kampf/Missionar

**Problem:** Die Proben suchten Ziele per Exploration auf einer Zufallskarte und
skippten, wenn nichts in Reichweite war.

**Umsetzung:**

- Ein echtes Java-Autosave wird mit `prepare-e2e-savegame.py` zu einer reproduzierbaren
  Native-Trade-Fixture umgebaut. Die Fixture wurde vom Java-Server erfolgreich geladen
  und die Savegame-Konsistenzprüfung war erfolgreich. Die fertige Fixture liegt unter
  `Tools/fixtures`; zur Neuerzeugung benötigt das Skript ein Java-generiertes Autosave als
  Eingabe.
- Die Native-Trade-Probe lädt diese Fixture und führt jetzt einen echten Kauf samt
  Haggle-Abschluss aus. Der Client verifiziert sowohl den Goldabzug als auch den
  Cargo-Zuwachs; der Test deckte erforderliche `NativeTrade`-/Item-IDs, das
  `Goods.location`-Attribut und einen fehlenden `GoodsContainer` am Fixture-Wagon auf.
- Beim Fixture-Login wird `LOAD_GAME` korrekt als In-Game-Zustand behandelt.
- `prepare-scenario-e2e.py` erzeugt aus der Native-Trade-Fixture einen Java-validierten
  Szenario-Spielstand mit AI-Kolonie, verhandelnder Einheit, Scout, Missionar und
  benachbartem Kampfziel. Die drei Proben laden diesen Spielstand statt zufällig nach
  Zielen zu suchen.
- Java-Wire-Formate korrigiert: Diplomatie ist asynchron, Kampf nutzt `attack` statt
  `move`, und Missionare verwenden die `missionary`-Nachricht mit Richtung. Die Probe
  erkennt Missionsplatzierung und Spionage am aktualisierten Modellzustand.
- Java-XML schreibt `playerType` und `stance` in Kleinbuchstaben. Die Parser ordnen
  jetzt `colonial`/`native` und die kleingeschriebenen Haltungen korrekt zu.
- Die Trade-Route-Probe nutzt eine feste Nation, einen kleineren Archipel-Spielstart
  und rotierende Explorationsrichtungen; so erreicht sie den Küstenstart reproduzierbar.
- Die Diplomatie-Probe sendet den Vorschlag und verarbeitet eine Antwort, falls der
  Server eine liefert. Im deterministischen Savegame kam in 30 Sekunden keine AI-Antwort;
  die Java-Nachricht bestätigt den Vorschlag beim Sender nicht synchron.
  Dieser frühere Fehler ist inzwischen behoben (fehlende Objekt-ID und
  kleingeschriebener Status); der aktuelle Gesamtlauf bestätigt die AI-Annahme.
- Die separate Tribut-Fixture entsteht mit `--tribute` aus demselben Basisstand.
  Acht zusätzliche lokale Veteranen als Dragoner sichern eine klare militärische
  Überlegenheit. Eine echte AI nimmt Frieden gegen 100 Gold an; die Probe prüft
  unveränderte Klauseln, PEACE und den exakten Goldzuwachs. Der Java-Server
  bestätigt die Spielstand-Konsistenz beim Laden.

**Verifikation:** `STRICT_SKIPS=1 Tools/e2e-java-server.sh` — 11 bestanden, 0
übersprungen, 0 fehlgeschlagen. Die Szenario-Fixture besteht außerdem die Java-
Savegame-Konsistenzprüfung.

### Phase 93 — Update-Abdeckungs-Audit & Schiffe in Transit

**Problem:** `Game.applyUpdate` ignoriert unbekannte Tags still (`default: break`). Genau so
sind `<highSeas>` und `<europe>` unbemerkt durchgerutscht.

- Debug-Audit aller 11 Proben durchgeführt (`E2E_LOG_LEVEL=debug`): `<region>` wurde
  ignoriert; `<tileItemContainer>` wurde beim Tile-Parsing bereits verarbeitet, aber
  vom äußeren Audit irrtümlich als unbekannt gemeldet; `chooseFoundingFather` und
  `newLandName` wurden bewusst zur UI weitergereicht, aber als unhandled geloggt.
- Region-Objekte werden jetzt beim Map-Load und in Updates gespeichert und im Tile-
  Infofeld mit ihrem Servernamen angezeigt. Bereits geparste Tile-Item-Container sowie
  weitergereichte Prompts werden nicht mehr als unbekannt gemeldet.
- Schiffe ohne Tile-Standort zeigen im Infofeld Reiseziel und Restdauer; die
  Europa-Ankunftsmeldung wird angezeigt. Auswahl-/Next-Unit-Logik ohne Tile und die
  sichtbare UI im echten Spiel müssen noch geprüft werden. Der Next-Unit-Pfad wurde
  mit einer High-Seas-Einheit regressionsgetestet: die Einheit ist auswählbar, hat
  kein Kartentile und erscheint nicht unter den Einheiten mit offenen Kartenbefehlen.
- Verifiziert: vollständige Swift-Tests (85) und `swift build --target FreeColApp`
  sind erfolgreich. Der Debug-Audit meldete keine übrigen unhandled-Tags. Seit dem
  zusätzlichen Abandonment-Probe hat der Java-Gesamtlauf 11 Pässe, 1 Skip und 0 Fehler;
  die native UI-Sichtprüfung bleibt offen.
- **Offen:** Sichtprüfung in der nativen App von Transit-/Ankunftsanzeige,
  Einheitenwahl und der durch Spezifikationspreise befüllten Europa-Kaufliste.

**Nachprüfung 31. Oktober:**

- Inspektor und Europa-Hafen verwenden dieselbe Reiseanzeige: Ziel, Restdauer
  mit „Runde/Runden“, unbekannte Ziele ohne fälschliche „Neue Welt“-Vorgabe.
- Europa-Ankunft wird deutsch und mit Schiffsname angezeigt.
- Die Auswahl von Schiffen auf See und in Europa bleibt bei Modellupdates erhalten;
  zuvor wurde sie ohne Kartentile gelöscht. Reiseeinheiten blockieren keine Kartenbefehle.
- Native AppKit-/SwiftUI-Fenster prüfen und rendern Überfahrt (1/2 Runden), Ankunft,
  Hafen und spezifikationsbasierte Kaufpreise bei 600 × 480 Punkten.
- Damit ist das Layout mit reproduzierbaren Modelldaten geprüft; eine weitere
  manuelle Sichtprüfung während einer realen Java-Überfahrt bleibt möglich.
- Ausschiffen unterscheidet nun Küstenlandung (`move` des Passagiers auf Land)
  von direktem Ausladen im Hafen/Europa (`disembark`). Passagiere auf Wache sind
  bewegbar, sofern Bewegungspunkte verbleiben; 0 Punkte werden sichtbar erklärt.
  Der Hafenbefehl wird nicht mehr auf einem Wasserfeld gesendet. Die zusätzliche
  Java-Probe bestätigt direktes Ausladen in Europa trotz 0 Bewegungspunkten;
  die Gameplay-Probe bestätigt die Küstenlandung. Native Fenster und TCP-Tests
  decken beide Bedienwege sowie Serverablehnungen ab.

**Aufwand:** 1 Tag.

---

## Cluster B — Restliche E2E-Abdeckung (Hoch)

| Phase | Inhalt | Anmerkung |
|-------|--------|-----------|
| 94 | ✅ Kolonie aufgeben (`abandonColony`) | Deterministische Fixture; Java entfernt die Kolonie und gibt das Tile frei. Dabei wurde das Swift-Parsing von Java-`remove xLength/x0` korrigiert. |
| 95 | ✅ Echte Diplomatie- und Tribut-Annahme | Java-AI akzeptiert Frieden plus 100 Gold Geschenk sowie separat Frieden gegen 100 Gold Tribut. Haltung, unveränderte Klauseln und exakter Goldabzug/-zuwachs werden geprüft. Bewaffnete Landeinheiten öffnen den Tributeditor mit geeigneten Klauseln. UI-Gegenangebote verwenden Spieler- statt Objekt-IDs, behalten die serverseitige Version und verlieren neue Antworten beim Abschluss von `ask` nicht mehr. |
| 96 | ✅ Konkreter `emigrateUnit`-Slot | Java-Probe wählt Slot 1 und prüft, dass exakt der angebotene Recruit-Typ und der Goldabzug im Modell erscheinen. Das Fountain-of-Youth-Slot-1-Antwortformat bleibt über die bestehende Mock-Server-Probe abgedeckt; ein zufälliger realer Fountain-Auslöser ist nicht Teil dieser Fixture. |

Aufwand gesamt: 1–2 Tage.

---

## Cluster C — Wartbarkeit (Mittel)

### Phase 97 — CLI-Refactor (erster Schritt umgesetzt)

`ProbeSupport.swift` enthält Test-Helfer und `TestDelegate`; die reinen Offline-Tests
liegen in `OfflineTests.swift`; die bisherigen Smoke-/Gameplay-/Reject-/Trade-Route-
Proben wurden nach `Probes/LegacyE2EProbes.swift` verschoben. Die weiteren Proben liegen
bereits einzeln unter `Probes/`. Der CLI-Einstieg wurde von ca. 6000 auf ca. 3200 Zeilen
reduziert. Nächster Refactor-Schritt: die noch inline in `main.swift` stehenden
Mock-Server-Integrationstests und verbleibende Legacy-Proben in eigenständige Dateien
ziehen und dabei gemeinsame Login-/Turn-Helfer extrahieren.

---

## Cluster D — UI/UX (Mittel)

Erst nach Cluster A, damit die UI auf verifiziertem Modell aufsetzt.

| Phase | Inhalt |
|-------|--------|
| 98 | ✅ Produktionsvorschau und priorisierbare Build-Queue waren bereits vorhanden |
| 99 | ✅ Einheitenfähigkeiten, Erfahrung, Rolle und Cargo-Details |
| 100 | ✅ Karten-Overlays für Ressourcen, Handelsrouten und Ziele/Pfade; Minimap bleibt |
| 101 | ✅ Berichtsfilter, Sortierung und CSV-Export |

---

## Cluster E — Robustheit (Mittel)

| Phase | Inhalt |
|-------|--------|
| 102 | ✅ Auto-Reconnect mit Statusanzeige und bestätigungspflichtiger Kernaktions-Queue |
| 103 | ✅ Zentrale deutsche Fehlerbehandlung für synchrone Antworten, asynchrone Fehler und StringTemplates. Spezifische Java-Aktionsfehler, Verbindungsabbruch und Zeitüberschreitung mit Hinweis auf unklaren Ausführungszustand; unbekannte Diagnosen bleiben sichtbar. |
| 104 | Performance/Speicher — erst nach Profiling mit Instruments |

---

## Cluster F — Optional (nur auf Wunsch)

Save/Load, Metaserver-Browser, erweiterte Diplomatie- und Handelsmechaniken. In den Docs
bisher bewusst als Nicht-Ziele geführt.

## Phasen 105–106 — Spielbarkeit und Karteninformationen

Die nachfolgenden Phasen priorisieren konkrete Bedienlücken vor ungeprüften
Performanceänderungen. Phase 104 bleibt vom Instruments-Profil abhängig.

### Phase 105 — Verlässliche Marschbefehle (implementiert)

- Ziel setzen, Ziel löschen und Befehle löschen warten auf die Serverantwort.
- Während eines offenen Bewegungs-/Zielbefehls sind konkurrierende Zieländerungen
  gesperrt. Abgelehnte Änderungen behalten den bisherigen Modellzustand.
- Leere `destination`-Attribute entfernen Ziele korrekt. Ohne Verbindung gibt
  es keine Erfolgsmeldung. Zieländerungen werden nicht offline wiederholt.
- Die bereits implementierte rundenübergreifende Bewegung und gelbe Route bleiben
  erhalten; TCP-Regressionen prüfen Zielwechsel, Ablehnung und Abbruch.

### Phase 106 — Originalgrafiken für Rohstoffvorkommen (implementiert)

- Alle zwölf klassischen Bonusgrafiken werden über den bestehenden Importer
  reproduzierbar eingebunden.
- Erforschte Felder zeigen Vorkommen regulär auf der Karte, im Koloniegelände
  und in der Feldinformation. Die Ressourcenebene ergänzt Namen und Mengen.
- Unbegrenzte Vorkommen (`quantity=-1`) erhalten keine irreführende negative
  Mengenanzeige. Unbekannte Mod-Ressourcen behalten ihre Textinformation.
- Ressourcen verschwinden nach dem entsprechenden vollständigen Feld-Update.

**Abnahme:** Swift-Regressionen und native Fensteraufnahmen für normale Karte und
Ressourcenebene, vollständige Testsuite und Neubau des App-Bundles.

**Ergebnis:** 162 Swift-Tests ohne Fehler; native Aufnahmen mit Vorkommen und
Ressourcenbeschriftung geprüft; App-Bundle gebaut. Die isolierte Java-Probe
`disembark` bestätigt zusätzlich Ziel setzen/löschen anhand der Serverupdates
sowie die anschließende Rückreise mit Passagier. Kein Skip, kein Fehler.

---

## Phasen 107–108 — Deutsche und verlässliche Handelsrouten

### Phase 107 — Deutscher Handelsrouteneditor (implementiert)

- Routenliste, Haltepunkte, Aktionen, Europa und Validierungsmeldungen sind deutsch.
- Die Warenauswahl nutzt dieselben deutschen Warennamen wie die übrige Oberfläche.
- Waren und Aktionsschaltflächen brechen um; der Editor bleibt scrollbar.
  Eine native Layout-Regression prüft die schmale Fensterbreite von 680 Punkten.

### Phase 108 — Sichere Zuweisung und Haltepunkte (implementiert)

- Nur eigene Waren-Transporter können vorhandene eigene Routen erhalten.
  Die Spezifikationsfähigkeit `carryGoods` ist maßgeblich; reine
  Passagiertransporter und Kolonisten werden nicht zugelassen.
- Zuweisen, Entfernen und Wechsel des aktuellen Halts warten auf Serverbestätigung.
  Konkurrierende Befehle sind währenddessen gesperrt. Abgelehnte Aktionen ändern
  den lokalen Auftrag nicht; ohne Verbindung gibt es keine Offline-Wiederholung.
- Haltepunkte werden gegen die gespeicherte Route geprüft, nicht gegen einen
  noch ungespeicherten Editorentwurf. Leere `tradeRoute`-Attribute löschen die
  Zuweisung auch bei partiellen Modellupdates.
- TCP-Regressionen prüfen Ablehnung, Zuweisung, ungültige Indizes, Haltwechsel,
  Entfernen und fehlende Verbindung. Die isolierte Java-Probe prüft zusätzlich
  die bestätigte Entfernung einer zuvor zugewiesenen Route.

**Abnahme:** Vollständige Swift-Tests, native Layout-Regression, isolierte
Java-Probe `traderoute` ohne Skip sowie Neubau des App-Bundles.

**Ergebnis:** 167 Swift-Tests ohne Fehler, darunter die native
680-Punkte-Layoutprüfung. Die Java-Probe bestätigt Zuweisung, Haltwechsel,
Bereichsprüfung und Entfernen der Route: 1 bestanden, 0 übersprungen,
0 fehlgeschlagen. Das App-Bundle wurde erfolgreich neu gebaut.

## Nächste Schritte nach Phase 108

1. Phase 93: optional zusätzliche manuelle Sichtprüfung während einer echten
   Java-Überfahrt; native Fixture-Ansichten sind bereits abgedeckt.
2. Phase 104: Performance/Speicher erst nach reproduzierbarem Instruments-Profil bearbeiten.
3. Routenverwaltung weiter absichern: Anlegen, Speichern und Löschen verwenden
   noch den bisherigen Sendepfad. Diese separaten Aktionen ebenfalls gegen
   Ablehnung und Verbindungsabbruch prüfen, bevor die Routenautomatik erweitert wird.

Phase 102 speichert nur Kernaktionen, die über `sendCoreGameplayAction` laufen.
Nach Wiederverbindung werden sie niemals automatisch wiederholt; jede Aktion kann
einzeln erneut gesendet oder verworfen werden. Bei unklarer Serververarbeitung schützt
die Bestätigungsabfrage vor unbeabsichtigter doppelter Ausführung.

## Betrieb der E2E-Suite

```bash
Tools/e2e-java-server.sh                          # alle Proben, Summary am Ende
ONLY="recruitment combat" Tools/e2e-java-server.sh  # einzelne Proben
STRICT_SKIPS=1 Tools/e2e-java-server.sh           # Skips gelten als Fehler (Exit 2)
LOCAL_FREECOL_DIR=../freecol JAVA_BIN=/opt/homebrew/opt/openjdk/bin/java \
  STRICT_SKIPS=1 Tools/e2e-java-server.sh         # gesamter Lauf ohne Docker
```

Voraussetzung: Docker und das Image `docker-freecol-server:latest`
(`docker compose -f ../freecol/docker/docker-compose.yml build`) oder ein lokal
gebauter Checkout mit `FreeCol.jar` und `data/`. Lokal nutzt jede Probe eigene
Verzeichnisse und standardmäßig Port 3559; ein belegter Port führt zum Abbruch.

## Verwandte Dokumente

- `Docs/Plans/plans.md` — Gesamtplanung und Phasenprotokoll
- `Docs/Plans/freecol-client-roadmap.md` — Roadmap
- `Docs/Plans/phase90-recruitment-immigration-e2e-plan.md` — Beispiel für die korrigierten Wire-Formate
