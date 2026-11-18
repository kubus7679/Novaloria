# Umsetzungsplan: Colopedia um Regelwissen erweitern

## Ziel
Die Colopedia soll wichtige Spielmechaniken verständlich erklären und Werte aus dem aktiven Server-Regelwerk einschließlich Mods anzeigen. Bestehende Katalog- und SwiftUI-Struktur bleibt erhalten; Inhalte werden auf Deutsch, Englisch und Spanisch gepflegt.

## Änderungen
- `ColopediaEntry.facts(using:)` um verfügbare Spec-Felder für Waren, Rollen und Ressourcen sowie ausgelassene Einheiten-, Gelände-, Gebäude- und Verbesserungsdaten erweitern.
- `ColopediaCatalog.entries(specification:)` um aktive Rollen und Ressourcen ergänzen; mod-definierte IDs erhalten Namen und vorhandene Fakten.
- Die sieben bestehenden Konzepte auf feste Classic-Werte und veraltete Aussagen prüfen; Kernartikel zu Kolonieentwicklung, Produktionsketten, Handel/Markt, Erkundung und indigenen Siedlungen ergänzen.
- Neue Regel-Labels in den deutschen, englischen und spanischen `ColopediaCatalog.strings` lokalisieren. Konzepttexte eigenständig formulieren und variable Spielwerte nicht als universell fest darstellen.
- Katalogtests für Spec-Fakten, Mod-IDs, fehlende Daten, Übersetzungen und Links erweitern. Die vorhandene Darstellung nur bei einem konkret nachgewiesenen Layoutproblem anpassen.

## Prüfung
- Zuerst gezielte Colopedia-XCTest-Fälle ausführen.
- Danach `swift build --target Novaloria` und die vollständige `swift test`-Suite ausführen.
- Klassische und modifizierte Regeln in Deutsch, Englisch und Spanisch prüfen.

## Grenzen
- Keine Parseränderungen, solange die gewünschten Regelwerte in `Specification` bereits verfügbar sind.
- Keine dynamischen Nationen-/Gründerväterartikel in diesem Schritt, da deren vollständige Detailmodelle im Parser fehlen.
- Regelquellen dienen der Faktenprüfung; Formulierungen werden nicht wörtlich übernommen.