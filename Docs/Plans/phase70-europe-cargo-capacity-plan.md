# Phase 70 — Europe Purchase Cargo Capacity

## Ziel

Prevent Europe market purchases from exceeding the selected carrier's actual
remaining goods capacity, matching Java FreeCol cargo slots.

## Umsetzung

- [x] Parse `space` and `spaceTaken` from unit types and inherit missing values
      through `extends`.
- [x] Calculate occupied slots from goods stacks (100 goods per slot) and
      carried units.
- [x] Include remaining room in the selected goods type's partially filled
      stack, as Java `Unit.getLoadableAmount` does.
- [x] Limit the UI buy amount by affordability and free cargo capacity.

## Validierung

- `swift build --target Novaloria` erfolgreich.
- `swift test`: 69 Tests erfolgreich, inklusive Cargo-Space-Inheritance und
  Loadable-Amount-Grenzfällen.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; der reale
  Markt-Roundtrip kaufte und verkaufte 100 Pferde.
