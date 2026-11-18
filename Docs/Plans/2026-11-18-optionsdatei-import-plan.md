# Optionsdatei beim Erstellen eines Spiels laden

## Ziel

Beim Einrichten eines neuen Spiels kann eine zuvor exportierte Optionsdatei ausgewählt werden. Ihre Werte werden in die für die aktuelle Installation und Mod-Auswahl geladene Konfiguration übernommen.

## Umsetzung

- Options-XML anhand von Options-IDs mit der vorhandenen Konfiguration abgleichen.
- Bei Spezifikationen mit Mods den vollständigen Spieloptionsblock statt eines vorangestellten Mod-Optionsblocks auswählen.
- Importierte Werte gegen lokale Typen, Auswahlmöglichkeiten und Grenzen validieren und nur bei vollständigem Erfolg übernehmen.
- Eine Datei-Auswahl in der Ansicht zum Erstellen eines Spiels ergänzen.
- Roundtrip- und Fehlerfalltests zur Konfigurationslogik ergänzen.
- Regressionstest für Mod-Optionen vor dem Hauptoptionsblock ergänzen.

## Prüfung

`swift test --filter NewGameTests`