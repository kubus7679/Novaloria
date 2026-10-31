# Architektur-, Performance- und Sicherheitsplan

> **Stand:** 31. Oktober 2026  
> **Umsetzung:** Phasen 1, 2 und 4 sind abgeschlossen. Phase 3 enthält bereits
> viewport-basiertes Zeichnen, räumliche Tile-Indizes und reproduzierbare
> XCTest-Zeitvergleiche samt Canvas-Path-Proxy. Der Index wurde nach Messung
> speicherschonender gestaltet. Der Login warnt vor unverschlüsseltem Netzwerk
> und weist ungültige Ports ab. Ein natives UI-Profil und TLS-Unterstützung
> bleiben offen. Für Phase 6 sind jetzt Instruments-Signposts für den Aufbau
> der Renderdaten und die Canvas-Zeichenbefehle vorhanden; Messungen in der
> laufenden App und belastbare Allocations-Daten stehen noch aus.

## Prüfergebnisse

### Sicherheit und Robustheit

- Das TCP-Framing sammelte Bytes ohne Zeilenumbruch unbegrenzt an. Der XML-Parser
  hatte außerdem keine Größen-, Tiefen- oder Knotengrenzen. Ein fehlerhafter oder
  übergroßer Server-Frame konnte dadurch unnötig viel Speicher und CPU binden.
- Auch vollständige Frames konnten sich in der unbeschränkten `AsyncStream`
  unbegrenzt aufstauen, wenn der Empfänger langsamer als der Server war. Die
  Warteschlange ist jetzt auf acht Frames begrenzt; bei Überlauf wird die
  Verbindung mit einem sichtbaren Ressourcenlimit-Fehler beendet, statt Nachrichten
  stillschweigend zu verwerfen.
- TCP-Frames wurden je Empfangsblock in UTF-8 umgewandelt. Ein geteilter
  Mehrbyte-Zeichensatz konnte dadurch beschädigt werden.
- Zeilenumbrüche in Attributwerten wurden nicht maskiert und konnten das
  newline-terminierte Wire-Framing aufbrechen. Der Encoder maskiert diese
  Zeichen jetzt als XML-Referenzen; `send(raw:)` lehnt mehrzeilige Eingaben ab.
- Debug-Logs enthielten Teile vollständiger Nachrichten; darin können z. B.
  Chat-Inhalte oder Spielernamen stehen.
- Die Verbindung akzeptiert einen `Int`-Port, der bisher beim Aufbau per
  Force-Unwrap in `UInt16` umgewandelt wurde.
- Die Login-Maske setzte ungültige Port-Eingaben bisher stillschweigend auf
  `3541` zurück. Sie zeigt nun den erlaubten Bereich an und deaktiviert die
  Verbindung, bis ein gültiger Port eingegeben ist.
- Das FreeCol-Wire-Protokoll verwendet unverschlüsseltes TCP. Eine transparente
  TLS-Änderung wäre nicht kompatibel; Verbindungen sollten bis zu einer
  serverseitig unterstützten Lösung als nicht vertraulicher Transport behandelt
  werden.

### Performance

- `MapView` suchte für jedes Tile erneut linear alle Kolonien nach der passenden
  Tile-ID ab. Das ist bei `T` Tiles und `C` Kolonien `O(T × C)` und wurde durch
  einen einmalig aufgebauten Tile-Index auf `O(T + C)` reduziert.
- Tile-Daten werden pro Render-Aufbau weiterhin sortiert. Die Zeichenoperationen
  sind jetzt auf das sichtbare Viewport-Fenster begrenzt; Trefferprüfung und
  Tile-ID-Lookups verwenden direkte Dictionary-Zugriffe statt linearer Kartenscans.
  Referenztests sichern identisches Treffer- und Viewport-Verhalten. Erste
  Canvas-Path-Proxy-Messungen liegen für 80×100 und 160×200 Tiles vor. Der Index
  speichert dieselbe sortierte Tile-Liste statt zusätzlicher Zeilen-, Koordinaten-
  und ID-Wörterbücher. Das echte SwiftUI-/Rasterizing-Verhalten bleibt damit
  weiterhin ungemessen.
- Der Bildcache ist an die endliche Menge gebündelter Assets gebunden; aktuell
  ist kein dynamisches Wachstum durch entfernte Eingaben erkennbar.

### Architektur und Wartbarkeit

- Die Modulgrenzen zwischen Protokoll, Spielmodell, Client und SwiftUI-App sind
  bereits vorhanden. Die Empfangslogik und das Zeilen-Framing waren jedoch eng
  gekoppelt; das Framing ist jetzt ein separat testbarer Typ, und der
  Netzwerk-Callback übergibt Daten zur Verarbeitung an den `Connection`-Actor.
- `FreeColApp/GameState.swift` bleibt ein großer Einstiegspunkt; Fehler-Mapping
  wurde aus der UI-Logik gelöst. CLI-Integrationstests liegen jetzt nach
  Lifecycle, Session, Gameplay und Nachrichtenfluss getrennt.
- Actor-isolierte CLI-APIs werden in den extrahierten Tests korrekt mit `await`
  aufgerufen; der CLI-Build meldet keine Actor-Isolationsdiagnosen mehr.

## Phasen

| Phase | Priorität | Inhalt und Abnahmekriterien |
|---|---|---|
| 1 — Protokollgrenzen | Hoch, abgeschlossen | Frame-Limit von 16 MiB für Senden und Empfangen; AsyncStream auf acht wartende Frames begrenzen und Überlauf explizit melden; UTF-8 erst nach vollständiger Zeile dekodieren; XML auf 128 Ebenen und 250.000 Elemente begrenzen; externe Entitäten nicht auflösen; ungültige Ports als Fehler behandeln; einzeiliges Framing durchsetzen und Attribut-Zeilenumbrüche maskieren; Nachrichteninhalte nicht protokollieren. Tests decken Fragmentierung, Größenüberschreitung, UTF-8, XML-Tiefe und XML-Escaping ab. |
| 2 — Fehlerbehandlung | Mittel, abgeschlossen | Serverfehler-Mapping in `ServerErrorMessage` aus `GameState` herausgelöst; reale Java-Texte und unbekannte Meldungen werden unabhängig von UI-/Actor-Zustand getestet. |
| 3 — Kartenprofiling | Teilweise abgeschlossen | Canvas zeichnet nur Tiles, deren Bounds den Viewport schneiden. `TileSpatialIndex` beschleunigt Hit-Tests; Canvas-Path-Proxy-Messungen vergleichen alle Tiles gegen das Viewport-Fenster auf zwei Kartengrößen. Ein vollständiges SwiftUI-Zeichen-/Rasterizing-Profil bleibt offen. |
| 4 — CLI-Aufteilung | Mittel, abgeschlossen | 60 Mock-Server-Integrationstests in fünf thematische Dateien verschoben; `main.swift` auf den 9-zeiligen CLI-Einstieg reduziert. Login-/Zug-Helfer extrahiert und Actor-Zugriffe explizit asynchron gemacht; Swift-6-Actor-Isolationsdiagnosen sind damit beseitigt. |
| 5 — Transportvertraulichkeit | Blockiert durch Server-Kompatibilität | Der Login warnt sichtbar vor unverschlüsseltem TCP. Nächster Schritt: TLS-/Tunnel-Unterstützung mit FreeCol-Server abstimmen und erst nach dokumentiertem Wire-Protokoll sowie erfolgreichem Interoperabilitätstest implementieren. Keine inkompatible TLS-Aushandlung erfinden. |
| 6 — Kartenprofiling | Hoch, teilweise umgesetzt | Der Index hält nun nur die sortierte Tile-Liste; `MapView` teilt deren Copy-on-Write-Puffer und fragt Tile-IDs direkt im Game-Modell nach. Die bisherigen Release-XCTest-Zahlen bezogen sich auf die alte, überlappende Kartengeometrie und müssen nach deren Korrektur neu erhoben werden. Die Tests bleiben CPU-Proxys ohne Canvas-Rasterizing, Sprite-/Text-Zeichnung oder vollständigen `renderData`-Aufbau. Instruments-Signposts markieren `RenderDataBuild` und `CanvasCommands`; Laufzeitmessungen sowie eine getrennte Allocations-Auswertung sind offen. `XCTMemoryMetric` liefert hier prozessweite, zwischen Fällen nicht verlässlich vergleichbare Spitzenwerte. |
| 7 — Transport-Sicherheitsabnahme | Abhängig von Phase 5 | Verbindungsfehler, Zertifikatsprüfung und Downgrade-Verhalten gegen den TLS-fähigen Server/Tunnel testen; Klartext nur für explizit konfigurierte lokale/vertrauenswürdige Verbindungen zulassen. |
| 8 — Eingabevalidierung | Mittel, abgeschlossen | Login-Port wird nur im Bereich 1–65535 akzeptiert; ungültige Eingaben werden sichtbar erklärt und können nicht still auf einen anderen Port zurückfallen. |

Phasen 1–4 sowie 8 wurden mit `swift test`, `swift build --target FreeColApp` und
`swift build --target FreeColProtocolCLI` geprüft. Die CLI-Integrationstests sind
zusätzlich über `swift run FreeColProtocolCLI` ausführbar. Phase 5 bleibt von einer
kompatiblen, serverseitig unterstützten TLS-/Tunnel-Lösung abhängig. Die neuen
Performance-Messungen vergleichen die Canvas-Path-Arbeit auf zwei Größen; daraus folgt
noch keine Aussage über die gesamte SwiftUI-Zeichenpipeline. Der lineare
Referenzfall erzeugt Diamond-Pfade für alle Tiles; der indexierte Fall sortiert,
selektiert das Viewport-Fenster und erzeugt nur dessen Pfade.

## Nächste Phasen

1. **Phase 6 abschließen:** App mit einer reproduzierbaren großen Karte starten und
   in Instruments die Signposts `RenderDataBuild` sowie `CanvasCommands` erfassen.
   Parallel SwiftUI/Core Animation für Layout, Rasterizing und Framezeiten prüfen;
   diese liegen außerhalb der Canvas-Signpost-Intervalle. Allocations in einem
   separaten, frischen Profil-Lauf messen und Referenz-/Indexläufe nicht anhand
   prozessweiter XCTest-Spitzenwerte vergleichen.
2. **Phase 5 vorbereiten:** Mit dem FreeCol-Serverprojekt klären, ob TLS nativ oder
   über einen unterstützten Tunnel bereitgestellt wird. Vor einer Implementierung
   müssen Protokoll, Serverversion, Zertifikatsvertrauen und Fehlerverhalten
   dokumentiert sowie ein Interoperabilitätstest festgelegt sein.
3. **Phase 7 erst danach ausführen:** Gegen den vereinbarten TLS-Endpunkt
   Zertifikatsfehler, Verbindungsabbruch und Klartext-/Downgrade-Verhalten testen.
   Bis dahin keine TLS-Aushandlung im Client erfinden oder unverschlüsselte
   Verbindungen stillschweigend als vertraulich behandeln.

## Bedienbarkeit und grafische Proportionen

- Kartenzeichnung, Minimap und Trefferprüfung verwenden dieselbe Geometrie:
  eine ganze Tile-Breite je Spalte, eine halbe Tile-Höhe je Zeile und eine
  halbe Tile-Breite Versatz in ungeraden Zeilen. Zuvor überlappten benachbarte
  Spalten; die Trefferprüfung verwendete zusätzlich einen anderen Zeilenversatz.
- Die Startvergrößerung beträgt 200 % statt 400 %. Menüs, Zoom, Karte,
  Einheitenaktionen und untere Befehlsleiste haben getrennte Layoutbereiche.
  Das Spielfenster ist mindestens 900 × 620 Punkte groß; lange Menüs und
  Aktionslisten bleiben scrollbar.
- Bewegung ist über eine explizite Zielwahl erreichbar. Das Inspizieren eines
  leeren Zielfelds verwirft die Einheitenauswahl nicht mehr. Die Kolonie öffnet
  sich per Doppelklick oder eigenem Button, unabhängig von der Einheitenauswahl.
- Europa und Kolonie besitzen eine feste Kopfzeile mit Schließen-Button und
  Escape-Tastenkürzel. Der Europa-Inhalt ist scrollbar und in der Höhe begrenzt;
  Berichtsnavigation und breite Tabellen sind ebenfalls scrollbar.
- Regressionstests prüfen Tile-Mittelpunkte bei fünf Zoomstufen, alle acht
  Bewegungsrichtungen, Auswahl-/Doppelklick-/Drag-Verhalten, erneutes Öffnen der
  Kolonie und Bewegung über eine lokale Verbindung. Native `NSHostingView`-
  Layouttests prüfen die Mindestfenstergröße und ein Europa-Panel mit 40 Rekruten.
  Das ersetzt keine vollständige Sicht-/Klickprüfung aller Spielfunktionen.

### Live-Nachprüfung am 31. Oktober 2026

- Bildschirmaufnahme und Bedienungshilfen funktionieren. Im Swift-Client wurde
  Europa über das View-Menü geöffnet und mit dem tatsächlichen Close-Button
  erfolgreich geschlossen.
- Der ausgewählte Pionier hat 0 Bewegungspunkte; beide Move-Buttons sind
  deaktiviert. Nach Auswahl der Karavelle mit 12 Bewegungspunkten ist Move aktiv.
  Die Zielwahl lässt sich öffnen und über Cancel wieder verlassen. Eine Bewegung
  wurde bewusst nicht ausgeführt und kein Zug beendet.
- Die Kolonie-Suche findet New Colony und zentriert die Karte. Automatisierte
  Karten-Doppelklicks öffneten bisher keinen Koloniedialog; dieser Bedienweg ist
  deshalb weiterhin nicht live abgenommen. Ein Fehler der Eingabeautomation ist
  dabei noch nicht ausgeschlossen.
- Im Java-Client lassen sich Ansicht und Europa über Accessibility öffnen und
  Europa über Schließen wieder verlassen. Die Kartenansicht bleibt leer und
  zeigt Warten auf: Frankreich; die Ursache ist nicht bestimmt.
- Sichtbare Restpunkte: großzügige Leerflächen in rechter Aktionsleiste und
  unterem HUD, technische Einheitenbezeichnungen und überlagerte Kolonielabels.
  Die Sitzungen bleiben geöffnet; Auswahl wurde auf den ursprünglichen Pionier
  zurückgestellt.

### Founding-Father-Auswahl

Die Live-Prüfung zeigte einen abgeschnittenen fünften Kandidaten im schmalen,
180 Punkte hohen Entscheidungsbereich. Die Auswahl nutzt jetzt einen eigenen,
220 Punkte hohen Bereich über die Fensterbreite mit adaptivem Kandidatenraster.
Namen und Kategorien umbrechen mehrzeilig; der Kandidatenbereich bleibt bei
größerem Inhalt scrollbar und wird explizit geclippt, damit er keine
Kartenbedienelemente überlagert. Ein nativer Layout-/Render-Test prüft alle fünf
Angebote bei 900 und 1453 Punkten Breite sowie das gesamte Mindestfenster.
Die Auswahl wurde in der laufenden Sitzung nicht beantwortet; die neue
Darstellung wird erst mit dem neu gebauten Client aktiv.

### Spieltest über drei Rundenwechsel

- Die laufende Multiplayer-Partie wurde von Runde 3 bis Runde 6 weitergespielt,
  jeweils mit Zugende im Swift- und Java-Client. Henry Hudson wurde als
  Gründervater gewählt; im Java-Client wurde ein friedlicher Erstkontakt
  bestätigt. Keine Käufe, Kriegserklärungen oder Einheitenauflösungen.
- Bestätigter Aktualisierungsfehler: End Turn blieb in der unteren Leiste
  deaktiviert, obwohl das Spielmenü denselben Befehl erlaubte. Die Karavelle
  hatte 12 MP und einen aktiven Move-Button in der Seitenleiste, unten war Move
  weiterhin deaktiviert. Zugwechsel wurden deshalb über das Menü ausgeführt.
- Ursache: Abgeleitete UI-Abfragen lasen das in-place veränderte Spielmodell,
  ohne dessen `gameUpdateID` zu beobachten. Der gemeinsame `cachedGame`-Zugriff
  beobachtet jetzt die Modellrevision. Ein Observation-Regressionstest schlug
  vor der Änderung für Zug-, Einheiten- und Spielerabfragen fehl und prüft jetzt
  auch die Wiederaktivierung im nächsten eigenen Zug.
- Kolonielabels wurden sichtbar vom Siedlungssprite übermalt. Sie werden jetzt
  in einem separaten Durchlauf nach allen Tile-Sprites mit dunkler Unterlage
  unterhalb der Siedlung gezeichnet. Einheitenkarten nutzen den vorhandenen
  Anzeigenamen-Helfer statt des vollständigen `model.unit.*`-Identifiers.
- Offen bleiben fehlende Terraintexturen/Farbflächen, großzügige HUD-Leerflächen
  und die nicht erfolgreich automatisierte Karten-Klickprüfung. Eine Bewegung
  wurde im Live-Spiel nicht bestätigt. Die Java-Karte zeigte im eigenen Zug
  Terrainfragmente statt einer vollständig leeren Fläche; die Ursache ist offen.
- Der laufende Prozess verwendet weiterhin den vorherigen Build. Die neuen
  Korrekturen benötigen einen Client-Neustart und sind noch nicht live abgenommen.

### Nachprüfung nach Neustart: Runde 6 bis 9

Live am 31. Oktober 2026 mit dem neu gestarteten Swift-Client und dem laufenden
Java-Original geprüft. Die Clients steuern unterschiedliche Spieler derselben
Partie; Sichtbereich, Einheitenbestand, Punktestand und Europa-Inhalt müssen
deshalb nicht identisch sein. Verglichen wurden Darstellung und Bedienstruktur,
nicht die Gleichheit spielerspezifischer Daten.

- Drei vollständige Rundenwechsel von 6 nach 9 wurden mit beiden Clients
  ausgeführt. Im Java-Client wurde zusätzlich ein Einwanderungs-Zugbericht
  bestätigt. Keine Käufe, Kriegserklärungen oder Auflösungen.
- Der Pionier wurde über „Move to Selected Tile“ auf das eigene Koloniefeld
  bewegt. Seine Darstellung wechselte auf das Zielfeld und die MP sanken von
  3 auf 0. Beide Move-Buttons wurden deaktiviert; in Runde 7 waren beide mit
  wiederhergestellten 3 MP aktiv. Auch in Runde 8 und 9 blieb der Zustand korrekt.
- End Turn funktioniert jetzt über einen sichtbaren Button. Während des
  Java-Zuges ist er deaktiviert und im nächsten eigenen Zug wieder aktiv.
- Kolonie per Karten-Doppelklick geöffnet und über Close geschlossen. Die
  früher erfolglosen Klickversuche waren kein belastbarer Nachweis eines
  App-Fehlers: Globale Mausereignisse funktionieren, direkt an den Prozess
  gesendete Ereignisse hatten die Kartenbedienung nicht ausgelöst.
- Koloniename mit dunkler Unterlage ist nun sichtbar. Auf demselben Feld
  überlagern sich weiterhin Einheiten- und Siedlungssprite.
- Europa lässt sich nach dem Neustart öffnen, schließen und erneut öffnen.
  Close bleibt auch bei einem auf 900 Punkte Breite verkleinerten Fenster
  sichtbar. Inhalt liegt unterhalb des sichtbaren Ausschnitts und benötigt
  Scrollen; eine vollständige Funktionsabnahme aller Handelsaktionen erfolgte
  nicht. Die Founding-Father-Auswahl wurde mangels neuer Anfrage nicht erneut
  live geprüft.
- Beim Verkleinern des maximierten Swift-Fensters verschwand das zuvor sichtbare
  Spielgebiet aus dem Kartenausschnitt; sichtbar blieb nur unerforschtes Terrain.
  Die Auswahl einer anderen Einheit über Next brachte das Gebiet zurück.
  Die Kamera sollte bei Größenänderungen denselben Kartenmittelpunkt behalten.
- Abschlusszustand: Runde 9, eigener Zug, Pionier auf dem Koloniefeld mit 3 MP.
  Europa ist geschlossen; die ursprüngliche große Fenstergröße ist
  wiederhergestellt und das Spielgebiet sichtbar.

### Vorschläge aus dem Vergleich mit dem Java-Original

Die folgenden Punkte dokumentieren die ursprünglichen Empfehlungen.
Ihre inzwischen erfolgte Umsetzung und deren Validierung stehen im nächsten Abschnitt.
Der native macOS-Stil soll erhalten bleiben; sinnvoll ist die Übernahme der
Informationsstruktur des Originals, nicht seiner dekorativen Rahmen.

| Priorität | Beobachtung im Vergleich | Vorgeschlagene Anpassung / Abnahme |
|---|---|---|
| P1 | Swift zeigt mehrere einfarbige Terrainrauten und harte Kanten. Im Java-Original sind Wald, Küstenübergänge und Terrainüberlagerungen erkennbar. | Asset-Zuordnung und Rendering-Layer anhand tatsächlich gelieferter Tile-Typen prüfen; Grundterrain, Wald, Küsten und Verbesserungen getrennt darstellen. Dieselben bekannten Felder ohne unbeabsichtigte Farb-Fallbacks rendern. |
| P1 | Größenänderung verliert den sichtbaren Kartenausschnitt. | Kamera-Mittelpunkt bei Resize erhalten und an Kartengrenzen begrenzen. Zwischen großem Fenster und 900 Punkten Breite wechseln, ohne die aktive Einheit aus dem Blick zu verlieren. |
| P2 | Einheiteninformationen stehen rechts oben und rechts unten; Befehle erscheinen zusätzlich unten links. Dazwischen entstehen große Leerflächen. | Einen gemeinsamen Einheiteninspektor mit Porträt, Name, MP, Ladung und kontextuellen Befehlen verwenden; Minimap und Zugende in einem kompakten HUD bündeln. Alle bisherigen Aktionen müssen erreichbar bleiben. |
| P2 | Das Original zeigt lokalisierte Namen; Swift mischt Deutsch und Englisch und zeigt weiterhin CamelCase wie HardyPioneer oder expertFarmer. | Gemeinsame Lokalisierung für Einheiten, Waren, Menüs und Status. MP zusätzlich verständlich als Bewegungspunkte anzeigen; keine technischen Bezeichner in Spieleransichten. |
| P2 | Der aktive Move-Button im rechten Inspektor wirkt im dunklen Fenster zeitweise deaktiviert, obwohl Accessibility ihn als aktiv meldet. | Kontrast für aktive, deaktivierte und fokussierte Buttons konsistent gestalten; den Zustand nicht allein durch subtile Grautöne vermitteln. |
| P2 | Einheiten verdecken auf Koloniefeldern das Siedlungssprite; das Original vermittelt Zugehörigkeit über zusätzliche Markierungen. | Auswahlrahmen, Eigentümermarkierung und Stapelzähler ergänzen; Siedlung und Einheiten unterscheidbar platzieren. Bedeutung und Datenbasis der Anzeige „(0)“ prüfen und eindeutig beschriften. |
| P2 | Europa beginnt im Swift-Client mit Rekruten und einer langen Kaufliste. Hafen, Ladung und Markt sind dadurch nicht gleichzeitig sichtbar. Das Original gliedert Hafen, Docks, Fracht, Reise und Markt räumlich. | Bereiche oder Tabs für Hafen/Fracht, Markt und Rekrutierung/Ausbildung; auf breiten Fenstern nebeneinander, auf schmalen separat erreichbar. Warenpreise, ausgewähltes Schiff und Ladung ohne Durchscrollen der gesamten Kaufliste zugänglich machen. |
| P2 | Bei 0 Gold sind kostenpflichtig beschriftete Recruit-Buttons aktiv, Buy dagegen deaktiviert. | Erschwinglichkeit und mögliche kostenlose Auswanderung fachlich unterscheiden und sichtbar erklären. Keine pauschale Sperre, bevor die jeweilige Serveraktion geprüft ist. |
| P3 | Die Swift-Kolonie ist vorwiegend ein langes Formular; Produktion, Arbeiter und Aktionen konkurrieren um denselben Scrollbereich. | Kompakte Übersicht mit Bevölkerung, Nahrung und Bauauftrag; eigene Bereiche für Arbeiter/Felder, Gebäude und Lager. Destruktive Aktionen wie Auflösen/Verlassen in ein getrenntes Menü verschieben. Ein direkter Live-Vergleich beider Koloniedialoge steht noch aus. |
| P3 | Das Original präsentiert Ereignisse als Zugbericht; im Swift-HUD ist der Zugstatus klein und teilweise nur farblich hervorgehoben. | Wiederaufrufbaren Ereignisbereich sowie ein klares, einheitlich platziertes Zugende mit Hinweisen auf offene Befehle vorsehen. |

Empfohlene Reihenfolge: zuerst Kartenlesbarkeit und Kamera (P1), danach
konsolidiertes HUD und Lokalisierung, anschließend Europa und Kolonie. Für jede
Etappe die breite Ansicht und das kleine Fenster sowie den Wechsel zwischen
eigenem und fremdem Zug live prüfen.

### Umsetzung der Oberflächenempfehlungen

- **Karte und Kamera:** Alle 23 klassischen Terrain-Typen erhalten die
  Original-Grundtexturen. Wald/Höhen, stilkodierte Küsten und vereinfachte
  Straßen-/Fluss-/Pflugoverlays werden separat gezeichnet. Der Auswahlrahmen
  übermalt das Terrain nicht mehr. Die Kamera erhält bei Größenänderungen den
  bisherigen Mittelpunkt innerhalb der Kartengrenzen; ein Menüpunkt zentriert
  die Auswahl erneut.
- **Einheiten und HUD:** Ein rechter Inspektor ersetzt die mehrfachen
  Einheitenkarten und die separate Befehlsleiste. Kontextaktionen bleiben
  scrollbar erreichbar; seltener benötigte und destruktive Befehle liegen im
  Befehlsmenü. Minimap, Zugbericht, offene Befehle und Zugende stehen kompakt
  unten. Aktive Hauptaktionen sind blau, deaktivierte deutlich zurückgenommen.
- **Lesbarkeit:** Gemeinsame deutsche Namen für Einheiten, Waren, Gebäude,
  Terrain und Zustände sowie übersetzte Hauptmenüs. Unbekannte Mod-Typen
  behalten vorhandene Spezifikationsnamen. Einheitenstapel zeigen einen Zähler,
  Eigentümerfarben sind auf Karte, Minimap und Inspektor konsistent.
  Siedlungssprite und Einheit stehen versetzt. „Bevölkerung“ zählt gemeldete
  Einwohner bzw. bekannte Koloniearbeiter, nicht Schiffe oder wartende Einheiten
  auf dem Koloniefeld.
- **Europa:** Drei direkt erreichbare Bereiche für Hafen/Fracht, Markt und
  Rekrutierung/Ausbildung; Schiffsauswahl und Schließen bleiben außerhalb des
  Scrollinhalts. Zur konsistenten Bedienung wird auch bei größerer Breite
  dieselbe Bereichsnavigation verwendet, nicht die dekorative Java-Anordnung.
  Hafen und Docks unterscheiden direkt anwesende Einheiten von Passagieren
  und Reisenden. Auch im Spielerbaum verschachtelte Europa-/Hochsee-Einheiten
  werden eingelesen. Bezahlte Anwerbung berücksichtigt Einwanderungsschwelle,
  Mindestpreis und Gold; kostenlose Auswanderung bleibt möglich. Ohne die
  Fähigkeit zur Rekrutenauswahl erfolgt sie ausdrücklich zufällig.
- **Kolonie:** Dauerhafte Kurzinfo für Bevölkerung, Nahrung und Bauauftrag,
  vier Bereiche für Übersicht, Arbeiter/Felder, Gebäude/Bau und Lager/Fracht.
  Arbeiter sind direkt auswählbar, einschließlich bekannter Gebäudearbeiter.
  Schiffe werden nicht als Arbeiter angeboten. Ungültige/leere Warenauswahlen
  aktivieren keine Produktions-/Frachtbefehle. Verlassen liegt getrennt im
  Verwaltungsmenü mit Bestätigung.
- **Ressourcen:** Reproduzierbarer Import mit
  `python3 Tools/import-ui-resources.py ../freecol`; Herkunft und GPL-Lizenz
  sind in der README dokumentiert und die Lizenz wird mitgeliefert.

#### Validierung und Grenzen

- `swift test`: 120 Tests erfolgreich, einschließlich Terrain-/Küstenabdeckung,
  Kamera-Resize/Begrenzung, Rekrutierung, Hafenfilter, Bevölkerung,
  Arbeiterauswahl, Eigentümerfarben und der bestehenden Zugwechsel-Regressionsprüfungen.
- Native SwiftUI/AppKit-Renderbilder mit befüllten Fixtures kontrolliert:
  Spielansicht bei 900 × 620 und 1200 × 800 Punkten, alle Europa-Bereiche
  bei 600/760 × 480 und alle Kolonie-Bereiche bei 640/760 × 480.
  Die Prüfung der kleineren Dialogbreiten deckte erzwungene Mindestbreiten
  durch lange Bereichsreiter auf; die korrigierten Layouts passen ohne
  abgeschnittene Navigation oder Schließen-Schaltfläche.
- `swift build --product FreeColApp` und `git diff --check` erfolgreich.
- Die laufende Mehrspielerpartie wurde für diese Implementierung nicht
  unterbrochen oder neu gestartet. Die vorangehende Live-Prüfung der Runden
  6–9 bleibt getrennt von dieser Fixture-/Layoutabnahme. Eine erneute
  Mehrspielerabnahme des neuen Builds steht nach dem Neustart noch aus.
- Keine pixelgenaue Java-Nachbildung: Moderne animierte Terrainübergänge
  werden nicht übernommen; Verbesserungen sind vereinfachte Overlays.

### Nachbesserung: Kolonieaktionen, Direktbewegung und Colopädie

- **Umbenennen und Arbeiterzuweisung:** Diese Java-Spielaktionen werden jetzt
  als `question` gesendet und erst nach der `reply`-Antwort ausgewertet.
  Serverfehler erscheinen im Koloniedialog. Das Modell lädt auch Arbeiter aus
  verschachtelten Gebäuden und Koloniefeldern; ihre Auswahl überlebt
  vollständige und partielle Kolonieaktualisierungen.
- **Geländeübersicht:** Unter „Arbeiter und Felder“ sind Zentrum und acht
  Nachbarfelder mit Originalterrain, Arbeitern und Produktionsauswahl sichtbar.
  Feldklick weist den ausgewählten Arbeiter zu; ein belegtes Feld tauscht die
  Arbeiter atomar über `rearrangeColony`. Dabei werden Produktion und Rolle an
  den neuen Arbeitsplatz angepasst. Gebäude werden nicht pauschal als
  Ein-Personen-Arbeitsplätze behandelt.
- Das Zentrum arbeitet automatisch. Unbekannte, fremde oder anderweitig
  belegte Felder bleiben gesperrt; Wasser benötigt ein Dock.
  Unbeanspruchtes Land wird vor der Zuweisung kostenlos beansprucht.
  Native Grundstücke werden nicht ungefragt gekauft oder gestohlen.
- **Plausible Aktionen:** Missionarsausrüstung benötigt eine geeignete Person
  sowie Europa oder einen passenden eigenen Koloniestandort. Schiffe und
  Wagen sind ausgeschlossen. Geländeverbesserungen werden nur für geeignete
  Arbeiter mit passender Ausrüstung direkt auf der Karte angeboten.
  Innenarbeiter werden nicht mehr beim Durchklicken der Karteneinheiten gewählt.
- **Rechtsklick:** Eine ausgewählte Einheit folgt direkt einem bekannten,
  passierbaren Weg zum Ziel und verbraucht dabei die verfügbaren Bewegungspunkte.
  Jeder Schritt wartet auf die Serverantwort; doppelte Bewegung und Zugende
  sind währenddessen gesperrt. Option + Rechtsklick öffnet das Feldmenü.
  Ein verbleibendes Fernziel bleibt gespeichert, wird im nächsten Zug aber noch
  nicht automatisch fortgesetzt: Dafür erneut das Ziel rechts anklicken.
- **Colopädie:** 206 importierte klassische Einträge in neun Kategorien mit
  deutschen Namen, Beschreibungen, historischen Texten, Originalgrafiken,
  Spielwerten und anklickbaren Querverweisen. Suche und Kategorieauswahl ersetzen
  die bisherigen statischen Tabellen. Verfügbare Werte kommen aus der
  Serverspezifikation; Beschreibungstexte beziehen sich ausdrücklich auf das
  klassische Regelwerk. Fehlt eine passende Originalgrafik, erscheint ein
  aussagekräftiges Kategoriesymbol. Der Ressourcenimport ist reproduzierbar;
  Herkunft und Lizenz sind in der README aufgeführt.

#### Abnahme dieser Nachbesserung

- `swift test`: 130 Tests, keine Fehler. Neue Regressionen prüfen insbesondere
  verschachtelte Arbeiter, Auswahlstabilität, Feldsperren, Missionars- und
  Pioniereignung, `question`/`reply` für Kolonieaktionen und mehrschrittige
  Bewegung, Platztausch sowie sichtbare Serverablehnungen.
- Native SwiftUI/AppKit-Bilder aller neun Colopädie-Kategorien, der befüllten
  Kolonieübersicht und des Geländes kontrolliert. Die Colopädie wurde auch
  bei 700 × 420 Punkten gerendert; Navigation und Schließen bleiben erreichbar.
- Ein separater lokaler Java-Server auf Port 3559 mit eigenen Datenverzeichnissen
  bestand die bestehende Gameplay-Probe: Kolonie gründen und umbenennen,
  Lagerverwaltung, Handelsrouten, Europa-Handel, Bewegung und Zugwechsel.
  Arbeiterzuweisung und Direktbewegung des SwiftUI-Zustands sind zusätzlich über
  TCP-Tests mit kontrollierten Serverantworten geprüft, nicht durch Bedienung
  der laufenden Mehrspielerpartie.
- `bash Tools/build-app.sh` erstellt das aktualisierte startbare App-Bundle;
  `git diff --check` ist erfolgreich. Die laufende Java-App und die persönliche
  Partie wurden nicht unterbrochen; der isolierte Testserver wurde beendet.
