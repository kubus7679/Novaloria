# Phase 54 — Inbound Blockers (Implementiert)

Ziel: Keine stillen oder blockierenden Server-Nachrichten mehr. Eine
Gegenprüfung gegen den Java-Client (`freecol/`) ergab mehrere eingehende
Nachrichten, die der Swift-Client gar nicht oder nur als Log-Zeile behandelte.
Das blockierte Kern-Gameplay (Founding Fathers, Niederlage, Spielende).

## Umfang

### 1. `chooseFoundingFather` (Kernprogression)
- Eingehend: Angebotene Väter stehen als Attribute `trade`, `exploration`,
  `military`, `political`, `religious` (Wert = Father-ID) im Payload.
- Neu: `PendingServerDecisionType.foundingFather`, `FoundingFatherOption`,
  `pendingFoundingFathers`, `foundingFatherLabel(_:)`.
- UI: Auswahl-Buttons je Kandidat im Pending-Overlay (`GameView`).
- Outbound-Guard von `phase == .lobby` auf `lobby || inGame` erweitert.

### 2. Niederlage (`setDead`)
- `GameStateManager` reicht `setDead` jetzt an die UI weiter (Modell wird
  weiterhin angewendet).
- Neu: `isDefeated`, `isUndead`, `applySetDeadMessage`, `enterRevengeModeFromDefeat`.
- UI: Niederlage-Overlay mit „Enter Revenge Mode" / „Disconnect".

### 3. Lokaler Logout
- `GameStateManager` reicht `logout` an die UI weiter, damit der
  „Your session has ended"-Pfad erreichbar ist.

### 4. Spielende (`gameEnded`)
- Neu: `isVictorious`, `gameEndedHighScore`, `continueAfterVictory`,
  `retireAfterVictory`.
- UI: Sieg-Overlay mit „Continue Playing" / „Retire".

### 5. `incite` / `spySettlement` / `scoutSpeakToChief`
- `incite`: Bestätigungs-Overlay (Feind + Gold) → `confirmPendingIncite` /
  `declinePendingIncite`.
- `spySettlement`: öffnet das Kolonie-Panel der ausspionierten Siedlung
  (`openColonyPanel(colonyId:)`).
- `scoutSpeakToChief`: Info-Overlay mit ergebnisabhängigem Text
  (`scoutReportText`), Quittierung per OK.

### 6. Lobby-Echo
- `updateGameOptions` / `updateMapGeneratorOptions` werden in einen
  Client-Spiegel (`Game.optionValues`) gemergt statt ignoriert.

## Verdrahtung

- `GameStateManager.serverPromptTags` und `GameState.serverPromptTags` um
  `chooseFoundingFather`, `scoutSpeakToChief`, `spySettlement`, `incite`,
  `setDead` (UI zusätzlich `nativeTrade`, `diplomacy`) erweitert, damit auch in
  `<update>`/`<multiple>` verschachtelte Prompts nach oben gereicht werden.
- `matchesPendingPrompt` und `canRespondToPendingDecision` um die neuen Typen
  ergänzt.
- `resetSessionState` setzt Sieg-/Niederlageflags zurück.

## Tests

- XCTest (+7, gesamt 43): FF-Angebot/Labels, Scout-/Incite-Prompts,
  Sieg-Übergang, Manager-Forwarding für die neuen Prompts, Logout, `setDead`
  Modellentfernung, Options-Merge.
- CLI (+2, gesamt 130): „message loop forwards founding-father and death
  prompts"; angepasste Manager-Tests für `setDead`/`logout` (jetzt forwarded).

## Bekannte Grenzen

- `featureChange` (Fähigkeiten/Modifier/History) bleibt unverarbeitet; das
  Swift-Modell repräsentiert diese Konzepte nicht (Phase 60).
- Der Sieg-/Niederlage-Overlay ist minimal (kein Score-Detaildialog).
- `incite` bestätigt direkt; die Java-Variante zeigt vorher einen
  Tile-Anker-Dialog (rein visuell).
