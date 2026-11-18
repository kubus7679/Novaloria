# Classic Atlas: Karte und Inspector

## Ziel

Karte und rechten Inspector als zusammengehörige Präsentation überarbeiten. Die vorhandenen FreeCol-Grafiken und Mod-Overrides bleiben der visuelle Anker. Auswahl, Nebel, Hit-Testing, Kamera und Spielzustand ändern sich nicht.

## Abgestimmtes Konzept

- Stilrichtung: Classic Atlas, mit zurückhaltenden Meergrün-, Waldgrün-, Tinten- und Messingakzenten.
- Inspector: responsiv ab der bisherigen Breite von 260 Punkten, mit moderatem Wachstum bei breiten Fenstern.
- Kontext: Einheitenaktionen bleiben primär; der explizite Feldinfo-Umschalter bleibt erhalten.
- Umfang: Präsentation und Layout zuerst; Renderdaten- oder Minimap-Performance nur bei gemessener Regression.

## Umsetzungsschritte

1. Kartenmarkierungen in `Sources/Novaloria/MapView.swift` vereinheitlichen: zoomabhängige Feldkontur, ausgewählte Einheit mit zurückhaltendem Außenring und Messingakzent, Labels mit kontrastreichem Text und Besitzerfarbe als Rand/Akzent. Zeichenreihenfolge und Sichtbarkeitsregeln bewahren.
2. Inspector-Flächen und Inhaltsrangfolge in `Sources/Novaloria/InfoPanelView.swift` verfeinern. Vorhandene Einheitenbilder und Aktionen, Fracht, Feldinhalt und Modusvorrang erhalten.
3. Rechte Rail in `Sources/Novaloria/GameView.swift` moderat responsiv machen; Minikarte und Zugbericht bleiben oben. Aktuelle Änderungen an der Gründerväter-Auswahl nicht verändern.
4. Screenshots und Tests für kompakte und normale Fenster sowie mehrere Zoomstufen prüfen. Bei sichtbarem Render-Leistungsrückgang Änderungen lokal vereinfachen; keine unabhängige Architektur-Refaktorierung.

## Prüfung

- `MapInteractionTests.testSettlementLabelsLayoutAtMultipleZoomLevelsAndCanBeHidden`
- `MapInteractionTests.testHighSeasExitMapAndInspectorFitNativeWindow`
- `MapInteractionTests.testCoastalDisembarkControlsFitWithAndWithoutMoves`
- Optional UI-Snapshots über `FREECOL_UI_SNAPSHOTS` bei 900x620 und 1200x800 für Auswahl-, Feld-, Siedlungs- und Routenansichten.
- `swift build --target Novaloria`

## Betroffene Bereiche

- `Sources/Novaloria/MapView.swift`
- `Sources/Novaloria/InfoPanelView.swift`
- `Sources/Novaloria/GameView.swift`
- `Tests/FreeColProtocolTests/MapInteractionTests.swift` (nur falls die Änderung eine gezielte Regression-Assertion benötigt)
