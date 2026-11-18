# Umsetzungsplan: Protokollgrenzen-Regressionstests

## Ziel
Die implementierten Grenzen für XML-Knotenzahl und wartende Empfangsframes gegen Regressionen absichern.

## Änderungen
- XML-Test erzeugt ein flaches Dokument mit mehr als `maximumXMLNodes` und erwartet den Ressourcenlimit-Fehler.
- TCP-Test sendet mehr als `maximumQueuedFrames`, konsumiert zunächst nichts und prüft nach den gepufferten Frames den Ressourcenlimit-Fehler.
- Bestehende Testhelfer und Testdatei-Konventionen wiederverwenden.

## Prüfung
- Zuerst die beiden neuen Tests gezielt ausführen.
- Danach, sofern die lokale Toolchain das SwiftUI-Makroplugin bereitstellt, die vollständige `swift test`-Suite ausführen.

## Status
- Beide Tests sind in `Tests/FreeColProtocolTests/FreeColProtocolTests.swift` implementiert.
- `swiftc -frontend -parse` und `swift build --target FreeColProtocol` sind erfolgreich.
- Der gezielte XCTest-Aufruf konnte wegen des fehlenden `SwiftUIMacros.StateMacro`-Plugins nicht bis zur Testausführung gelangen.
