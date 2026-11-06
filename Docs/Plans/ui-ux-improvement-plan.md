# UI/UX-Verbesserungsplan — aktualisierte Bestandsaufnahme

> **Stand:** 6. November 2026, 12:37 Uhr
> **Prüfbasis:** Laufende macOS-App plus aktueller Arbeitsbaum
> **Status:** Mehrere frühere Vorschläge sind bereits umgesetzt. Dieser Plan
> beschreibt nur die verbleibenden Korrekturen und die notwendige Verifikation.

## Aktueller UI-Zustand

Die laufende Partie zeigt Runde 41/Jahr 1532, 178 Gold und eine ausgewählte
Schiffseinheit ohne Bewegungspunkte. Der Inspektor war zunächst ausgeblendet;
nach dem Öffnen zeigt er Einheit, Standort, Bewegungspunkte, Befehle,
Marschziel und Ladung. Die Karte nimmt den übrigen Platz ein.

| Bereich | Aktueller Stand | Konsequenz für die Planung |
|---|---|---|
| Zugleiste | Runde/Jahr und Gold sind kompakt sichtbar; „Zug beenden“ ist direkt erreichbar. Weitere Werte und der Inspektor liegen im Überlaufmenü. | Kein Neubau der Leiste. Breiten und Auffindbarkeit des Inspektors testen. |
| Fehlerbanner | Kompakte, schließbare Karte am Kartenrand. Sie zeigt „Aktion fehlgeschlagen“ und den Hinweis, dass die Einheit keine Bewegungspunkte mehr hat. | Darstellung ist bereits verbessert. Die Meldungskategorie ist für diesen Fall irreführend; die passende Aktion ist Warten, keine Recovery-Schaltfläche. |
| Einheiteninspektor | Ein-/ausblendbar; gruppierte Einheitenbefehle und Hilfetexte für deaktivierte Aktionen sind vorhanden. | Umschalter ist im Überlauf versteckt; Gründe sind überwiegend erst über Hilfe/Tooltip sichtbar. |
| Offene Befehle | Der Zähler „ohne Befehl“ ist eine Schaltfläche, die zur nächsten passenden Einheit springt. | Funktion existiert; Randfälle und visuelle Erkennbarkeit regressionsprüfen. |
| Kartenlabels | Siedlungsnamen werden nach Zoom und Auswahl priorisiert; überlappende Labels werden ausgelassen. Ein Sichtbarkeitsschalter existiert. | Algorithmus nicht neu bauen. Dichte Routen-/Label-Szenen visuell prüfen und nur bei reproduzierbarer Unruhe ändern. |
| Tastaturhilfe | Die Hilfe bezieht ihre Einträge aus dem registrierten Shortcut-Manager und zeigt die aktuelle Verfügbarkeit. | Keine statischen Beispielbelegungen zurückbringen; reale Bedienung noch manuell prüfen. |
| Sprache | Spielbefehle, Einstellungen, Status und Tastaturhilfe sind überwiegend deutsch. | Nur verbliebene app-eigene englische Texte nachweisen und korrigieren; macOS-Standardmenüs nicht unnötig ersetzen. |

### Hinweise zur Prüfbasis

- Die UI wurde live in einer Partie geprüft. Der Inspektor wurde zur Sichtprüfung
  geöffnet; das ändert keine Spiel- oder Serverdaten.
- Die Oberfläche und zugehörigen Quell-/Testdateien sind im Arbeitsbaum
  uncommittet geändert. Diese Änderungen sind fremder bzw. laufender Arbeitsstand
  und müssen vor einer Umsetzung geprüft, nicht überschrieben werden.
- Vorhandene Tests in `Tests/FreeColProtocolTests/MapInteractionTests.swift`
  und `Tests/FreeColProtocolTests/InteractionRepairTests.swift` decken Teile
  der Bewegungshinweise, UI-Größen und Fehler-Recovery ab. In dieser
  Bestandsaufnahme wurden keine Tests ausgeführt; ein sichtbarer Stand gilt
  deshalb nicht als vollständige Regressionfreigabe.

## Priorisierte Restarbeiten

### 1. Meldung ohne Bewegungspunkte korrekt einordnen

**Befund:** Im geprüften Zustand heißt die Karte „Aktion fehlgeschlagen“, obwohl
der Inhalt eine erwartbare Einschränkung erklärt: Die Einheit hat für diesen Zug
keine Bewegungspunkte mehr. Die rote Fehleroptik suggeriert einen Defekt. Eine
Recovery-Aktion wird für diesen Fall zu Recht nicht angeboten.

**Betroffene Stellen**

- `Sources/FreeColApp/GameView.swift` — `errorBanner(_:)`
- `Sources/FreeColApp/GameState.swift` — `errorMessage`,
  `errorRecoveryActionTitle`, Bewegungs-Guards
- `Tests/FreeColProtocolTests/InteractionRepairTests.swift`
- `Tests/FreeColProtocolTests/MapInteractionTests.swift`

**Umsetzung**

1. Zuweisungen und Lebenszyklus von `errorMessage` inventarisieren. Mindestens
   erwartbare Zustands-/Hinweismeldungen von lokalen Validierungsfehlern und
   tatsächlichen Serverablehnungen unterscheiden.
2. Für „keine Bewegungspunkte“ eine neutrale Hinweis-/Statusdarstellung
   verwenden, zum Beispiel „Diese Einheit hat für diesen Zug keine
   Bewegungspunkte mehr.“ Die rote Überschrift „Aktion fehlgeschlagen“ dort
   nicht anzeigen.
3. Hinweis weiterhin schließbar und nach einer relevanten Zustandsänderung
   aktualisierbar machen. Keine zeitgesteuerte Löschung verwenden, solange sie
   wichtige Serverfehler verdecken könnte.
4. Vorhandene Recovery-Aktionen ausschließlich für Fälle behalten, in denen
   die Aktion tatsächlich ausführbar ist (z. B. unpassendes Marschziel löschen
   oder Zielauswahl abbrechen). Für „keine Bewegungspunkte“ weder eine
   wirkungslose Recovery-Schaltfläche noch eine Erfolgsmeldung anzeigen.
5. Unbekannte Serverdiagnosen und Ablehnungen weiterhin vollständig sichtbar
   lassen; keine pauschale Unterdrückung oder Umwandlung in einen Hinweis.

**Abnahme**

- Kein-Bewegungspunkte-Fall erscheint nicht mehr als fataler bzw. fehlgeschlagener
  Vorgang, erklärt aber weiterhin verständlich, warum Bewegen nicht möglich ist.
- Bekannte Fehler mit Recovery behalten ihre passende Aktion.
- Unbekannte Serverfehler bleiben sichtbar und schließbar.
- Die Meldung bleibt bei 900 × 620 Punkten lesbar und verdeckt keine notwendige
  Kartenaktion.

**Prüfung**

- XCTest für Status-/Fehlerklassifikation, Meldung nach Zustandsupdate und
  Recovery-Fälle ergänzen bzw. vorhandene Tests anpassen.
- `swift test --filter InteractionRepairTests`
- `swift test --filter MapInteractionTests`
- `swift build --target FreeColApp`
- Native Sichtprüfung: Einheit mit 0 Bewegungspunkten, unerreichbares Ziel,
  unbekannte Serverablehnung.

**Priorität/Aufwand:** Hoch; etwa 0,5–1 Tag.

---

### 2. Einheiteninspektor und deaktivierte Aktionen auffindbar machen

**Befund:** Der Inspektor ist standardmäßig ausgeblendet und wird über das
Überlaufmenü geöffnet. Im geöffneten Zustand sind Aktionen wie „Bewegen…“ oder
„Aktivieren“ bei 0 Bewegungspunkten grau; die konkrete Begründung ist vor allem
als Tooltip verfügbar.

**Betroffene Stellen**

- `Sources/FreeColApp/GameView.swift` — `isInspectorVisible`, `topBar`,
  `unitQuickActions`
- `Sources/FreeColApp/GameState.swift` — bestehende
  `selectedUnitMoveDisabledReason`- und
  `selectedUnitActionUnavailableReason`-Guards
- `Sources/FreeColApp/GameCommands.swift` — bereits vorhandene
  Menü-/Inspektoraktionen
- `Tests/FreeColProtocolTests/MapInteractionTests.swift`

**Umsetzung**

1. Einen dauerhaft sichtbaren, eindeutig beschrifteten Inspektor-Schalter in
   der Spielleiste ergänzen oder die Sichtbarkeit im Überlaufmenü stärker
   kennzeichnen. Zustand (ein-/ausgeblendet) muss für VoiceOver zugänglich sein.
2. Beim Öffnen mit ausgewählter Einheit direkt das Einheitenpanel zeigen;
   beim Schließen Auswahl und Spielzustand erhalten.
3. Für zentrale deaktivierte Aktionen den Grund direkt im Panel oder als
   sichtbaren Statushinweis zugänglich machen. Tooltip als Ergänzung behalten,
   nicht als einzige Erklärung voraussetzen.
4. Dieselben GameState-Guards für Aktivierung und Erklärtext verwenden. Keine
   UI-seitige Kopie der Bewegungs-/Zugregeln anlegen.
5. Bei 0 Bewegungspunkten die Erklärung mit der Hinweisanzeige aus Arbeitspaket
   1 abstimmen, sodass sie nicht doppelt oder widersprüchlich erscheint.

**Abnahme**

- Inspektor ist ohne Öffnen eines Menüs auffindbar und mit Maus sowie
  Tastatur/VoiceOver bedienbar.
- Der ausgewählten Einheit entsprechende Inhalte erscheinen beim Öffnen;
  Ein-/Ausblenden ändert keine Auswahl oder Aktionen.
- Mindestens die häufigsten deaktivierten Aktionen erklären ihren Grund auch
  ohne Hover.
- Darstellung funktioniert bei 900 × 620 und 1200 × 800 Punkten, ohne Buttons
  oder Labels abzuschneiden.

**Prüfung**

- Bestehende Layouttests in `MapInteractionTests.swift` erweitern.
- Interaktion manuell mit ausgewählter beweglicher Einheit, Einheit ohne
  Bewegungspunkte und ohne ausgewählte Einheit prüfen.
- `swift test --filter MapInteractionTests`
- `swift build --target FreeColApp`

**Priorität/Aufwand:** Hoch; etwa 0,5–1 Tag.

---

### 3. Bereits vorhandene Interaktionsverbesserungen regressionsprüfen

**Ziel:** Die schon implementierten Funktionen aus dem letzten UI-Schritt
bleiben nach den obigen Änderungen verlässlich und werden nicht erneut gebaut.

**Umfang**

- Klick auf „N ohne Befehl“ wählt die nächste passende Einheit; bei leerer Liste
  gibt es keine scheinbar aktive Aktion.
- Eine Einheit ohne Kartentile (z. B. auf hoher See) wird ausgewählt, aber die
  Karte wird nicht auf ein ungültiges Feld zentriert.
- Die Shortcut-Hilfe zeigt echte registrierte Kürzel und reagiert auf
  Verfügbarkeit im aktuellen Spielzustand. Eingabefelder dürfen ihre
  Tastatureingaben behalten.
- Zugende-Dialog und „Zug beenden“ funktionieren unverändert.
- Der Überlauf enthält sekundäre Werte und bestehende Status-/Berichtsaktionen;
  keine Aktion ist durch die kompakte Leiste unerreichbar.

**Prüfung**

- Bestehende Tests in `MapInteractionTests.swift` und
  `InteractionRepairTests.swift` ausführen und gezielt fehlende Randfälle
  ergänzen.
- Manuelle Kurzliste: nächste Einheit ohne Befehl; Schiff auf See; Kürzelhilfe
  im Spiel und beim Eingabefeld; Zugende mit/ohne offene Einheiten.

**Priorität/Aufwand:** Hoch; etwa 0,5 Tag.

---

### 4. Kartenlabels und Routen bei dichter Darstellung validieren

**Befund:** Der Screenshot zeigt bereits priorisierte Siedlungsnamen ohne
offensichtliche Label-Kollision. Farbige Routen verlaufen jedoch über einer
detailreichen Karte. Es ist nicht belegt, dass dies aktuell einen konkreten
Bedienfehler verursacht.

**Betroffene Stellen**

- `Sources/FreeColApp/MapView.swift` — `drawSettlementLabels(on:data:context:)`
  und Routen-Rendering
- `Sources/FreeColApp/GameCommands.swift` — Kartenüberlagerungen und
  „Siedlungsnamen“
- `Tests/FreeColProtocolTests/MapInteractionTests.swift`

**Umsetzung**

1. Bestehende Zoomschwelle, Priorität ausgewählter Felder und
   Kollisionsvermeidung beibehalten; zunächst Tests und Screenshots statt
   paralleler Rendering-Logik ergänzen.
2. Je eine dichte und spärliche Karte bei kleinem, normalem und großem Zoom
   aufnehmen. Siedlungsnamen, Auswahlrahmen, Ressourcenebene sowie
   Handelsrouten separat und gemeinsam prüfen.
3. Nur bei reproduzierbarer Unlesbarkeit nachbessern: ausgewählte Einheit und
   aktives Ziel priorisieren, kollidierende nicht ausgewählte Labels reduzieren
   und Routendarstellung über den vorhandenen Overlay-Schalter kontrollierbar
   halten.
4. Sichtbarkeits-/Kollisionsberechnung muss weiterhin Fog of War respektieren;
   unbekannte Siedlungen oder Routen dürfen nicht indirekt verraten werden.

**Abnahme**

- Ausgewählte Einheit, Zielpfad und Siedlungsname sind in dichten Szenen
  unterscheidbar.
- Ausgeblendete Labels bleiben über Infofeld/Inspektor auffindbar.
- Kein Fog-of-War-Leak und keine Regression der vorhandenen Kartenoverlays.
- Keine Rendering-Änderung, falls die reproduzierbaren Screenshots keinen
  konkreten Mangel zeigen.

**Prüfung**

- Native Screenshots und vorhandene Map-Overlaytests bei 900 × 620 und
  1200 × 800 Punkten.
- `swift test --filter MapInteractionTests`

**Priorität/Aufwand:** Mittel; 0,5 Tag für Prüfung, zusätzliche Umsetzung nur
bei belegtem Problem.

---

### 5. Sprach- und Fensterbreiten-Abnahme

**Ziel:** Die neue kompakte UI bleibt verständlich und konsistent, ohne bereits
übersetzte Bereiche unnötig umzubauen.

**Umsetzung**

1. App-eigene feste Strings in Spielansicht, Inspektor, Überlauf, Status,
   Einstellungen, Tastaturhilfe, Sieg/Niederlage und Bestätigungsdialogen
   durchgehen. Betriebssystem-Menüeinträge getrennt behandeln.
2. Nur belegte englische App-Texte oder inkonsistente Begriffe korrigieren;
   bestehende Labels in `GameLabels` und Serverfehlerzuordnung wiederverwenden.
3. Fensterprüfung mit geschlossenem und geöffnetem Inspektor bei 900 × 620 und
   1200 × 800 Punkten durchführen. Sicherstellen, dass die Karte bei
   ausgeblendetem Inspektor den zusätzlichen Platz nutzt und die Leiste nicht
   horizontal scrollt.

**Abnahme**

- Keine unbeabsichtigten englischen app-eigenen Aktions-/Dialogtexte im
  geprüften Hauptablauf.
- Zentrale Werte, Zugende, Inspektor-Schalter und Status bleiben bei beiden
  Fenstergrößen erreichbar.
- Keine Änderungen an Standardbezeichnungen des Betriebssystems ohne konkreten
  Grund.

**Prüfung**

- Manuelle Sicht- und Bediencheckliste.
- `swift build --target FreeColApp`
- `swift test`

**Priorität/Aufwand:** Mittel; etwa 0,5 Tag.

## Reihenfolge und Abhängigkeiten

1. Arbeitspaket 1: Meldung korrekt klassifizieren.
2. Arbeitspaket 2: Inspektor auffindbar und Aktionen verständlich machen.
3. Arbeitspaket 3: vorhandene Interaktionen regressionsprüfen.
4. Arbeitspakete 4 und 5: Kartenlesbarkeit und UI-Abnahme.

Arbeitspaket 2 verwendet die Meldungsklassifikation aus Arbeitspaket 1. Die
übrigen Pakete sind unabhängig und können parallel geprüft werden.

## Gesamt-Abnahme

- Vorhandene Funktionen sind als vorhanden dokumentiert und werden nicht
  dupliziert.
- Bewegungs-/Serverfehler bleiben explizit; erwartbarer Mangel an
  Bewegungspunkten wird nicht als fataler Fehler dargestellt.
- Inspektor und offene Befehle sind ohne versteckte Bedienwege nutzbar.
- Shortcut-Hilfe, Kartenoverlays, Fog of War und deutsche UI sind in den
  betroffenen Zuständen geprüft.
- `swift build --target FreeColApp` und `swift test` sind nach der Umsetzung
  erfolgreich.
- Die uncommitteten UI-Änderungen wurden berücksichtigt und nicht überschrieben.

**Geschätzter Restaufwand:** etwa 2,5–4 Entwicklungstage einschließlich
Regression und visueller Abnahme; zusätzliche Karten-Rendering-Arbeit nur,
wenn Arbeitspaket 4 einen reproduzierbaren Mangel feststellt.
