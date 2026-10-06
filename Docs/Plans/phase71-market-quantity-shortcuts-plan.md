# Phase 71 — Market Quantity Shortcuts

## Ziel

Make the Europe market's computed trade limits quick to use without manually
entering the amount.

## Umsetzung

- [x] Add “Max Buy” to fill the amount with the current gold-and-cargo buy limit.
- [x] Add “Sell All” to fill the amount with the selected carrier's goods count
      (renamed to “Max Sell” and limited to one Java price step in Phase 79).
- [x] Disable shortcuts when the action is unavailable or the limit is zero.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 69 Tests erfolgreich.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Markttransaktion
  gegen Java erfolgreich.
