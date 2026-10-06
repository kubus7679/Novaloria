# Phase 78 — Market Price-Step Limits

## Ziel

Keep each Europe purchase within Java FreeCol's 100-goods price-adjustment
chunk, so the buy limit remains accurate while market prices can change between
transactions.

## Umsetzung

- [x] Expose the Java `GoodsContainer.CARGO_SIZE` value as the market price-step
      limit.
- [x] Cap UI and app-state purchase quantities by affordability, free cargo and
      one server pricing chunk.
- [x] Guard direct app-state buy/sell calls against exceeding their computed
      quantities.
- [x] Label the buy quantity as a per-order limit; Max Buy selects that amount.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 73 Tests erfolgreich, einschließlich Chunk-Grenze.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; der exakte
  Einheitenpreis-/Golddelta-Roundtrip bleibt gegen Java erfolgreich.
