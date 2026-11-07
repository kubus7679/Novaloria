# Phase 69 — Market Purchase Affordability

## Ziel

Make the Europe market's purchase limit match Java FreeCol's actual buying
rules and the player's current gold.

## Befund

Java `ServerPlayer.buyInEurope` checks affordability against
`amount × costToBuy` (in cargo-size chunks). It does not reject a purchase
because `MarketData.amount` is low; that amount contributes to price calculation
instead. Therefore market stock is not a valid purchase-quantity cap.

## Umsetzung

- [x] Replace the market-stock purchase cap with `gold / displayed buy price`.
- [x] Keep the sell cap tied to the selected carrier's actual goods amount.
- [x] Show the affordable purchase quantity and sale cargo in Europe.
- [x] Treat missing/non-positive prices and non-positive gold as zero buy limit.

## Validierung

- `swift build --target Novaloria` erfolgreich.
- `swift test`: 67 Tests erfolgreich, inklusive Affordability-Grenzfälle.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Java bestätigte
  weiter Kauf und Verkauf von 100 Pferden.

The follow-up in `phase70-europe-cargo-capacity-plan.md` adds the remaining
cargo-space bound to the affordability limit.
