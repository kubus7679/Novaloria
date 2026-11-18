# Analyseplan

## Ziel
Den aktuellen Stand der Codebasis gegen `architecture-performance-security-plan.md` prüfen und den dauerhaften Plan mit bestätigten Umsetzungen, offenen Risiken und nächsten Maßnahmen aktualisieren.

## Umfang
Gezielte Nachprüfung der Architektur-, Performance-, Sicherheits- und Robustheitsmaßnahmen sowie der zuletzt dokumentierten Ausschiff-Funktion. Keine Implementierungsänderungen im Rahmen dieser Analyse.

## Zu analysierende Bereiche
- Architektur und Wartbarkeit
- Performance und Kartenrendering
- Sicherheit und Protokollrobustheit
- Transportvertraulichkeit
- Zuletzt ergänzte Gameplay-/Netzwerkpfade (Ausschiffen)

## Untersuchte Komponenten
- `FreeColProtocol/Connection.swift`, `LineFramer.swift` und `XMLDecoder.swift`
- `FreeColProtocol/XML/XMLEncoder.swift` sowie Login-Sicherheitshinweis
- `Novaloria/TileSpatialIndex.swift` und die Render-/Signpost-Pfade in `MapView.swift`
- Ausschiff- und Küstenlandungslogik in `GameState.swift` sowie zugehörige Regressionen
- Vorhandener Architektur-, Performance- und Sicherheitsplan

## Findings

### Hoch
Keine bestätigte kritische Abweichung im geprüften Quellcode.

### Mittel
- Phase 5 bleibt offen: Der Client nutzt TCP ohne TLS und zeigt einen sichtbaren Warnhinweis. Eine sichere Transportlösung erfordert weiterhin Server-/Tunnel-Kompatibilität.
- Phase 6 bleibt unvollständig: Signposts markieren Renderdatenaufbau und Canvas-Befehle, aber Laufzeitmessungen mit Instruments, SwiftUI/Core Animation und eine getrennte Allocations-Messung sind nicht im Repository belegt.

### Niedrig
- Direkte Regressionstests für `maximumXMLNodes` und `maximumQueuedFrames` wurden ergänzt. Die XML-Prüfung erwartet den Ressourcenlimit-Fehler oberhalb der Knotengrenze; die TCP-Prüfung erwartet acht geordnet gelieferte Frames und danach den expliziten Queue-Überlauffehler. Die Ausführung ist lokal durch das fehlende SwiftUI-Makroplugin blockiert.

## Empfohlene Maßnahmen
1. Erledigt: Regressionstests für XML-Knotenzahl und Frame-Queue-Überlauf ergänzt; nach Wiederherstellung des SwiftUI-Makroplugins ausführen.
2. Phase 6 mit einer reproduzierbaren großen Karte in Instruments und SwiftUI/Core Animation abschließen; Allocations getrennt erfassen.
3. TLS-/Tunnel-Unterstützung erst nach abgestimmtem Serverprotokoll und Interoperabilitätstest angehen; bis dahin Warnhinweis beibehalten.

## Umsetzungsreihenfolge
1. Ergänzte Tests für die Ressourcenlimits mit einer vollständigen, funktionierenden XCTest-Toolchain ausführen.
2. Laufzeit- und Speicherprofil für die Karte erheben.
3. Serverkompatibilität und Transportvertraulichkeit abstimmen; anschließend Phase 7 abnehmen.

## Offene Fragen und Annahmen
- Die Prüfung erfolgt anhand des lokalen Quellstands und Tests; Live-Instruments-Profile und produktive Serverkonfigurationen sind nicht Teil dieser Codeanalyse.
- `swift build --target FreeColProtocol` war erfolgreich, mit bestehenden `var`-statt-`let`-Warnungen in Nachrichtenimplementierungen.
- `swift test` brach beim Kompilieren ab, bevor Tests liefen: das lokale Swift-Toolchain-Setup konnte das externe `SwiftUIMacros.StateMacro`-Plugin nicht finden.
- Die Grenzwerttests wurden in `FreeColProtocolTests.swift` ergänzt. `swiftc -frontend -parse` und `swift build --target FreeColProtocol` sind erfolgreich; `swift test --filter ...` scheitert vor der Testausführung am fehlenden `SwiftUIMacros.StateMacro`-Plugin.
- Die übrigen offenen Maßnahmen betreffen externe Laufzeitmessungen und die Abstimmung für TLS/Tunnel.