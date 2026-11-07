# Phase 82 — Market Price Trend Indicators

## Ziel

Add visual trend indicators (up/down/stable) to market prices in the Europe panel based on recent price movements.

## Umsetzung

- [x] Calculate price trend (up/down/stable) over last N snapshots per goods type
- [x] Display trend indicator (↑/↓/→) next to prices in Europe market panel
- [x] Color-code trend indicators (green/red/gray)
- [x] Configurable trend window (default: last 5 snapshots)
- [x] Update trend on each market snapshot

## Validierung

- `swift build --target Novaloria` erfolgreich
- `swift test`: 74 Tests erfolgreich
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Trend-Indikatoren werden im Europe-Panel angezeigt