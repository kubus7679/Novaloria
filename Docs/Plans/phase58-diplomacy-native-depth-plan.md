# Phase 58 — Diplomatie/Native-Tiefe (Implementiert)

Ziel: Diplomatiesitzungen aktiv eröffnen, Native-Siedlungen auswerten,
Kampf bestätigen und Beziehungsdaten (Tension/Missionsverbote) anzeigen.

## Umfang

### 1. Aktive Diplomatie
- `diplomacyInitiationTargetsForSelectedUnit`: angrenzende fremde europäische
  Kolonien zur gewählten Einheit.
- `beginDiplomacy(otherColonyId:)`: synthetisiert ein `PROPOSE_TRADE`
  (`<diplomaticTrade context="DIPLOMATIC" sender/recipient status version>`)
  und öffnet damit den bestehenden Klausel-Builder in `DiplomacyView`.
- `pendingDiplomacyIsIncoming`: Accept/Reject nur bei eingehenden Vorschlägen;
  bei eigener Eröffnung „Close".
- Der bisherige, ungültige `sendDiplomacyMessage` (leeres `<diplomacy>`, das
  serverseitig an „Null diplomatic agreement" scheiterte) wurde entfernt.

### 2. Native-Siedlungen
- `Colony` parst für `<indianSettlement>`: `learnableSkill`, `wantedGoods0..2`,
  `mostHated`, `<alarm player value>`.
- `InfoPanelView` zeigt Skill, gewünschte Waren, meistgehassten Spieler und
  Alarm (rot ab 50).
- `askSkillAtSelectedUnit(direction:)` sendet `askSkill` und übernimmt die
  aktualisierte Siedlung; „Ask Skill"/„Learn Skill" im Native-Menü.

### 3. Kampfbestätigung
- `requestAttack(onTile:ranged:)` + `showAttackConfirmation` +
  `pendingAttackSummary` (Angreifer → Ziel, Melee/Ranged) und
  `confirmPendingAttack`; Angriffs-Buttons nutzen die Bestätigung.

### 4. Beziehungsdaten
- `Player` parst `<tension player value>` und `<banMissions player>`.
- Foreign-Report zeigt eine Tension-Spalte; Indian-Report listet Spieler mit
  Missionsverbot.

## Tests

- XCTest (+3, gesamt 59): IndianSettlement-/Tension-/BanMissions-Parsing,
  Diplomatie-Eröffnung (synthetisierter Vorschlag), Kampfbestätigungs-State.
- CLI: 130 grün.

## Bekannte Grenzen

- Die Eröffnungs-Diplomatie nutzt den vorhandenen Builder; es gibt keinen
  separaten „NegotiationDialog" mit KI-Bewertung wie im Java-Client.
- `mostHated`/Alarm werden angezeigt, aber nicht in die Native-Trade-Preise
  eingerechnet (Server entscheidet).
