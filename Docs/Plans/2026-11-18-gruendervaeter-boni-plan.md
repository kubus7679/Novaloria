# Umsetzungsplan: Gründerväter-Boni anzeigen

## Ziel
Die Colopedia und die Auswahl der Gründerväter sollen die jeweilige Wirkung klar beschriften und verfügbare Boni aus dem aktiven Regelwerk zeigen.

## Änderungen
- Die bestehende Gründervater-Kurzbeschreibung als explizites Faktenfeld „Bonus“ anzeigen, ohne sie in den Ansichten doppelt darzustellen.
- Produktions- und Freiheitsmodifikatoren aus `Specification` als zusätzliche Gründervater-Fakten formatieren.
- Mod-definierte Gründerväter aus der aktiven Spezifikation dynamisch in die Colopedia aufnehmen.
- Den aktiven Regelkontext an den Auswahlbildschirm weitergeben und dieselbe Faktenaufbereitung wie in der Colopedia verwenden.
- Neue Faktenlabels in Deutsch, Englisch und Spanisch lokalisieren.
- Regressionstests für statische und aktive Boni, Mod-Väter, beide Ansichten und Übersetzungen ergänzen.

## Prüfung
- Zuerst den gezielten Gründerväter-Test ausführen.
- Danach die Colopedia-/Auswahlbildschirmtests, `swift build --target Novaloria` und die vollständige Testsuite ausführen.

## Grenzen
- Verwendet die vorhandenen geparsten Produktions- und Freiheitsmodifikatoren; keine Änderung am Protokoll.
- Besondere klassische Wirkungen bleiben aus den lokalisierten Gründervater-Artikeln erhalten.