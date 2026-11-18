# WtP-Stil-Grafikmod für FreeCol und Novaloria

## Ziel

Ein installierbares FreeCol-Mod (`novaloria-atlas`) ersetzt die FreeCol-Spielgrafiken durch
eigene 3D-Renderings im Stil von „We the People“: texturreich, warm beleuchtet, weiche
Schatten. Die Grafiken überschreiben FreeCols Ressourcenschlüssel in den Originalmaßen und
liefern `.size2`-Dateien in doppelter Auflösung. Java-Client und Novaloria nutzen dasselbe Mod.

## Rahmen

- Renderer: Blender (headless, Cycles), gesteuert von einem uv-Projekt in `Tools/art`.
- Nur eigenes bzw. CC0-Material; WtP-/Civ4-Dateien werden weder kopiert noch nachgezeichnet.
- Mod-Lizenz GPL wie FreeCol; Alpha-Schablonen aus FreeCol-Grafiken sind damit zulässig.
- Umfang: alle Spielgrafiken. Ausgenommen: Porträts, Monarchen, Söldner, Wappen, UI,
  Pfad-/Auswahlmarker, unerforschte Kacheln.
- Zunächst ein Architekturstil; Nationsschlüssel zeigen per Alias auf gemeinsame Grafiken.
- Der Stil-Prototyp wurde freigegeben; Novaloria-Integration und Serienproduktion sind abgeschlossen.

## Etappe A — Werkzeuge und Pipeline

- [x] Repackaging-Generator und generierte Altdateien entfernen.
- [x] Blender benutzerlokal installieren (`brew install --cask --appdir=~/Applications blender`).
- [x] uv-Projekt `Tools/art` mit Manifest, Render-Runner, Nachbearbeitung, Paketierung, CLI.
- [x] pytest und ruff für Manifest, Masken, Ausrichtung, Paket und Namensregeln.

## Etappe B — Stil-Prototyp (Freigabe erforderlich)

- [x] Blender-Basis: 2:1-Kamera, warme Sonne, Himmelslicht, prozedurale PBR-Materialien.
- [x] Prototyp-Motive: acht Terrains, Misch- und Nadelwald, Hügel, Gebirge, Kolonist, Soldat,
      Dragoner, Karavelle, Planwagen, Rathaus, Zimmerei, Kirche, Kolonie klein/mittel,
      Nahrung, Felle, Rum, Werkzeug, Musketen, Getreide-Bonus, Gerücht.
- [x] Vergleichsblatt Original/Neu und synthetischer Kartenausschnitt in `build/art/review`.

## Etappe C — Novaloria

- [x] Mod-Lookups für Wald-/Hügel-Overlays, Strände, Flüsse, Wolken und Colopedia-Kategorien.
- [x] `.sizeN`-Hi-Res bevorzugen, Terrain-Variationen deterministisch je Kachel.
- [x] XCTests mit temporären Mod-Fixtures.

## Etappe D — Serienproduktion (nach Freigabe)

- [x] Terrain inkl. Variationen, Ozean-Varianten, Strände, Flüsse, Deltas, Wolken, Pflug.
- [x] Alle 160 referenzierten Waldressourcen mit deterministischen prozeduralen Varianten, Hügel, Gebirge.
- [x] Alle referenzierten Einheiten mit Rollen-/`.native`-Varianten, Schiffe, Wagen, Angriffsanimationen.
- [x] Siedlungen, Gebäude, Außenhintergründe, Waren, Bodenschätze, Gerücht, Ureinwohnerland.

## Verifikation

- Vollbuild: 540 Renderjobs, 807/807 Ressourcenschlüssel abgedeckt.
- Mod-ZIP: 1.095 Einträge; alle direkten Ressourcen und Aliase auflösbar; 10 SZA-Archive mit gültigen Frame-Referenzen.
- Tests: Python-Pipeline und fokussierte Swift-Modtests erfolgreich.
- Review-Ausgaben: `build/art/review/`.

## Abweichungen vom ursprünglichen Plan

- Materialien entstehen prozedural in Blender statt aus heruntergeladenen ambientCG-/Poly-Haven-
  Texturen. Bei Sprite-Größen von 32–256 px trägt das Downsampling Fotodetails kaum; dafür läuft
  die Pipeline offline und reproduzierbar. Download-Code (requests, pip-system-certs, SOCKS)
  entfällt deshalb vorerst und wird nur ergänzt, falls die Freigabe Fototexturen verlangt.
