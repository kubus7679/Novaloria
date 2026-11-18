# Swift-run-Warnungen beheben

## Hypothese

- `MockServer.port` ist `nonisolated let`; der Zugriff braucht kein `await`.
- Die Namensaktionen brauchen nur die Existenz von `cachedGame`, nicht dessen gebundenen Wert.

## Umsetzung

1. Das unnoetige `await` entfernen.
2. Beide ungenutzten Bindungen durch `cachedGame != nil` ersetzen und die Guards erhalten.
3. Mit `swift build --target Novaloria` pruefen, dass die drei Warnungen verschwinden.

Andere vorhandene Arbeitskopie-Aenderungen bleiben unveraendert.