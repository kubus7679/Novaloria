# Phase 85 — Multiplayer Turn Gating

## Ziel

Vollständige Parität mit dem Java-Client für Turn-Management in Multiplayer-Szenarien. Der Client muss korrekt erkennen, wann ein Spieler am Zug ist, und `endTurn`-Aktionen nur für den aktuellen Spieler erlauben. Zudem müssen Server-Rejections für illegale Turn-Aktionen korrekt gehandhabt und dem Benutzer angezeigt werden.

## Kontext

### Aktueller Stand

- `GameState.canEndTurn` prüft bereits `isLocalPlayersTurn`
- `endTurn()` wird nur gesendet, wenn `canEndTurn == true`
- Modell-Level Validierung existiert und ist getestet
- **Fehlend:** Live-Validierung gegen Java-Server mit 2+ Spielern

### Java-Server-Verhalten

Der Java FreeCol Server:
1. Sendet `<newTurn turn="N"/>` zu allen Clients beim Zugwechsel
2. Sendet `<setCurrentPlayer player="player-X"/>` um den aktuellen Spieler anzuzeigen
3. Akzeptiert `<endTurn/>` **nur** vom aktuellen Spieler
4. Sendet bei illegalem `endTurn` eine `<reply>` mit `<error message="...">`

### Offene Lücken

1. Kein E2E-Test mit mehreren Swift-Client-Instanzen
2. Keine UI-Indikation für "Warte auf Spieler X"
3. Server-Rejection für `endTurn` nicht live gegen Java getestet
4. Kein Turn-Timer (falls vom Server unterstützt)

## Umsetzung

### 1. Multiplayer-E2E-TestHarness

**Ziel:** Automatisierter Test mit 2+ Swift-Clients gegen einen Java-Server.

#### Architektur

```
Java FreeCol Server (Docker)
   ├─ Swift Client 1 (Player A - aktueller Spieler)
   └─ Swift Client 2 (Player B - wartet)
```

#### Implementierung

**Neue Datei:** `Sources/FreeColProtocolCLI/MultiplayerE2EHarness.swift`

```swift
struct MultiplayerE2EHarness {
    let serverHost: String
    let serverPort: Int
    let playerCount: Int
    
    /// Startet mehrere Client-Instanzen
    func runTest() async throws {
        // 1. Starte Server
        let server = try await startJavaServer()
        
        // 2. Verbinde alle Clients
        var clients: [FreeColProtocolCLI] = []
        for i in 0..<playerCount {
            let client = FreeColProtocolCLI()
            try await client.connect(to: serverHost, port: serverPort)
            try await client.login(nationIndex: i)  // Jeder Client wählt andere Nation
            clients.append(client)
        }
        
        // 3. Warte auf IN_GAME
        for client in clients {
            try await client.awaitGameState(.inGame)
        }
        
        // 4. Führe Test-Szenarien aus
        try await runTurnGatingTest(clients: clients)
        try await runEndTurnRejectionTest(clients: clients)
        
        // 5. Cleanup
        for client in clients {
            await client.disconnect()
        }
    }
    
    /// Test: Nur aktueller Spieler kann endTurn senden
    private func runTurnGatingTest(clients: [FreeColProtocolCLI]) async throws {
        // Warte, bis ein Client der aktuelle Spieler ist
        let currentPlayerClient = try await findCurrentPlayerClient(clients: clients)
        let otherClients = clients.filter { $0 !== currentPlayerClient }
        
        // Aktueller Spieler sendet endTurn
        try await currentPlayerClient.endTurn()
        
        // Warte auf newTurn/setCurrentPlayer
        for client in clients {
            try await client.awaitTurnChange()
        }
        
        // Verifiziere: Zugnummer wurde inkrementiert
        for client in clients {
            let turn = client.gameState.turnNumber
            assert(turn > 0, "Turn number did not increment")
        }
    }
    
    /// Test: Nicht-aktueller Spieler erhält Rejection
    private func runEndTurnRejectionTest(clients: [FreeColProtocolCLI]) async throws {
        // Finde Client, der NICHT der aktuelle Spieler ist
        let nonCurrentClients = clients.filter { 
            !$0.gameState.isLocalPlayersTurn 
        }
        guard let nonCurrentClient = nonCurrentClients.first else {
            return  // Alle sind aktuell oder nur 1 Spieler
        }
        
        // Versuche endTurn als nicht-aktueller Spieler
        let result = await nonCurrentClient.attemptEndTurn()
        
        // Muss scheitern
        assert(result.isRejected, "Non-current player endTurn should be rejected")
        assert(result.errorMessage != nil, "Should have error message")
        
        // Modell darf sich nicht ändern
        assert(nonCurrentClient.gameState.turnNumber == originalTurn, 
               "Turn should not advance for non-current player")
    }
}
```

#### CLI-Integration

Erweitere `main.swift`:

```swift
if env["REAL_SERVER_MULTIPLAYER_E2E"] == "1" {
    let harness = MultiplayerE2EHarness(
        serverHost: env["REAL_SERVER_HOST"] ?? "127.0.0.1",
        serverPort: Int(env["REAL_SERVER_PORT"] ?? "3541") ?? 3541,
        playerCount: Int(env["REAL_SERVER_PLAYER_COUNT"] ?? "2") ?? 2
    )
    try await harness.runTest()
    exit(0)
}
```

#### e2e-java-server.sh Integration

Füge neue Probe hinzu:

```bash
echo "==> Multiplayer Turn Gating probe (2+ players, turn ownership validation)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_MULTIPLAYER_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  REAL_SERVER_PLAYER_COUNT=2 \
  swift run FreeColProtocolCLI)
```

### 2. UI-Indikatoren für Turn-Status

**Ziel:** Klare visuelle Rückmeldung, welcher Spieler am Zug ist und wer wartet.

#### Änderungen in `Sources/FreeColApp/`

**GameState.swift:**
```swift
// Neu oder erweitert
@Published var currentPlayerId: String?
@Published var currentPlayerName: String?
@Published var isLocalPlayersTurn: Bool = false

// Berechnet
var turnStatusDescription: String {
    if isLocalPlayersTurn {
        return "Dein Zug (Zug #\(turnNumber))"
    } else if let name = currentPlayerName {
        return "Warte auf \(name) (Zug #\(turnNumber))"
    } else {
        return "Zug #\(turnNumber)"
    }
}
```

**GameView.swift oder StatusBarView.swift:**
```swift
// Status-Leiste am oberen Rand
StatusBarView()
    .padding(.horizontal)
    .background(Color.yellow.opacity(0.2))
    .animation(.default, value: gameState.isLocalPlayersTurn)

// In StatusBarView
struct StatusBarView: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        HStack {
            Text(gameState.turnStatusDescription)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(gameState.isLocalPlayersTurn ? .primary : .secondary)
            
            if gameState.isLocalPlayersTurn {
                Button("Zug beenden") {
                    gameState.endTurn()
                }
                .disabled(!gameState.canEndTurn)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 20, height: 20)
            }
        }
    }
}
```

#### Farbige Indikatoren

```swift
// Für jeden Spieler in der Lobby/Overview
PlayerRowView(player: player)
    .overlay(
        player.isCurrentPlayer ? 
            Color.green.opacity(0.3) : 
            Color.clear
    )
```

### 3. Server-Rejection-Handling für endTurn

**Ziel:** Korrekte Fehlerbehandlung, wenn der Server `endTurn` ablehnt.

#### Änderungen in `GameState.swift`

```swift
func endTurn() {
    guard canEndTurn else {
        errorMessage = "Du bist nicht am Zug."
        return
    }
    
    // Für Remote-Sessions: Nutze ask/reply
    if isRemoteGame {
        Task {
            do {
                let reply = try await client.ask(EndTurnMessage())
                if reply.containsError {
                    await handleServerRejection(reply.errorMessage)
                }
            } catch {
                await handleConnectionError(error)
            }
        }
    } else {
        // Local MockServer
        client.send(EndTurnMessage())
    }
}

private func handleServerRejection(_ message: String?) {
    let userFacingMessage = userFacingServerError(message) ?? message ?? "Unbekannter Fehler"
    errorMessage = userFacingMessage
    // Optionaler Toast/Alert
    showAlert = true
    alertTitle = "Aktion nicht möglich"
    alertMessage = userFacingMessage
}

// Mapping für bekannte Server-Fehlermeldungen
func userFacingServerError(_ serverMessage: String?) -> String? {
    guard let msg = serverMessage?.lowercased() else { return nil }
    
    if msg.contains("not the current player") {
        return "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug."
    }
    if msg.contains("end turn") && msg.contains("fail") {
        return "Der Zug konnte nicht beendet werden. Bitte versuche es erneut."
    }
    
    return nil
}
```

### 4. Turn-Timer (optional)

**Falls der Server Timer-Informationen sendet:**

```swift
// In GameState
@Published var turnTimeRemaining: Int?  // Sekunden

// Handling von Server-Nachrichten
func handleMessage(_ message: FreeColMessage) {
    switch message {
    case let m as SetCurrentPlayerMessage:
        // Timer zurücksetzen
        turnTimeRemaining = nil  // Oder Wert aus Message
    case let m as NewTurnMessage:
        // Timer zurücksetzen
        turnTimeRemaining = 60  // Standardwert
    case let m as AttributeMessage where m.key == "turnTime":
        turnTimeRemaining = Int(m.value)
    default:
        break
    }
}

// UI: Timer-Anzeige
if let seconds = gameState.turnTimeRemaining {
    Text("\(seconds)s")
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(seconds < 10 ? .red : .primary)
}
```

## Validierung

### 1. Unit Tests

**Neue Tests in `FreeColProtocolTests.swift`:**

```swift
// Test: canEndTurn ist false für nicht-aktuelle Spieler
func testCanEndTurnIsFalseForNonCurrentPlayer() {
    // Setup: 2 Spieler, Player B ist aktuell
    gameState.currentPlayerId = "player-b"
    gameState.localPlayerId = "player-a"
    
    XCTAssertFalse(gameState.canEndTurn)
    XCTAssertFalse(gameState.isLocalPlayersTurn)
}

// Test: canEndTurn ist true für aktuellen Spieler
func testCanEndTurnIsTrueForCurrentPlayer() {
    gameState.currentPlayerId = "player-a"
    gameState.localPlayerId = "player-a"
    gameState.gameStateValue = .inGame
    
    XCTAssertTrue(gameState.canEndTurn)
    XCTAssertTrue(gameState.isLocalPlayersTurn)
}

// Test: endTurn scheitert für nicht-aktuellen Spieler
func testEndTurnFailsForNonCurrentPlayer() {
    gameState.currentPlayerId = "player-b"
    gameState.localPlayerId = "player-a"
    
    gameState.endTurn()
    
    XCTAssertNotNil(gameState.errorMessage)
    XCTAssertEqual(gameState.turnNumber, originalTurn)
}
```

### 2. CLI Integration Tests

**Erweitere `FreeColProtocolCLI`:**

```swift
// Test: Multiplayer-Turn-Übergabe
func testMultiplayerTurnProgression() async {
    // Verbinde 2 Clients
    // Player 1 sendet endTurn
    // Player 2 wird neuer aktueller Spieler
    // Verifiziere Turn-Zähler
}

// Test: Illegal endTurn Rejection
func testEndTurnRejectionForNonCurrentPlayer() async {
    // Client als Player B verbinden
    // Player A ist aktuell
    // Client versucht endTurn
    // Verifiziere Error-Reply
}
```

### 3. E2E Tests gegen Java-Server

```bash
# Einzelne Probe
REAL_SERVER_MULTIPLAYER_E2E=1 REAL_SERVER_PLAYER_COUNT=2 \
  swift run FreeColProtocolCLI

# Vollständige Suite
Tools/e2e-java-server.sh  # Sollte Multiplayer-Probe enthalten
```

### 4. Manuelle Tests

- [ ] Starte 2 SwiftUI-App-Instanzen
- [ ] Verbinde beide mit demselben Server
- [ ] Player 1 bewegt Einheit und beendet Zug
- [ ] Player 2 sieht "Warte auf Player 1" und kann nicht endTurn senden
- [ ] Nach Player 1s endTurn: Player 2 wird aktueller Spieler
- [ ] Player 2 kann nun endTurn senden

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Multiplayer-E2E-Probe läuft gegen Java-Server | `Tools/e2e-java-server.sh` zeigt Probe erfolgreich | ⬜ |
| endTurn wird für nicht-aktuelle Spieler rejected | Server sendet Error-Reply | ⬜ |
| UI zeigt korrekten Turn-Status | StatusBarView anzeigen | ⬜ |
| canEndTurn ist korrekt berechnet | Unit-Tests passieren | ⬜ |
| Alle bestehenden Tests passieren | 80+ XCTest, 132+ CLI | ⬜ |
| Keine Regressionen | Alle E2E-Proben passieren | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Java-Server akzeptiert endTurn von falschem Spieler | Niedrig | Hoch | Vorab manuell testen, Server-Version prüfen |
| Mehrere Clients interferieren | Mittel | Hoch | Jeder Client nutzt eigene Session/Connection |
| Docker-Container Limit für mehrere Clients | Niedrig | Mittel | Port-Forwarding oder separate Container |
| Race-Conditions bei gleichzeitigen Aktionen | Mittel | Hoch | Sequenzielle Ausführung in Tests |
| Server-Disconnect bei vielen Clients | Niedrig | Hoch | Robustes Reconnect-Handling |
| UI-Updates nicht thread-safe | Mittel | Hoch | @MainActor für alle UI-Änderungen |

## Definition of Done

- [ ] `Tools/e2e-java-server.sh` enthält Multiplayer-Probe
- [ ] `FreeColProtocolCLI` implementiert Multiplayer-E2E-Harness
- [ ] Unit-Tests für Turn-Gating hinzugefügt (82+ Tests)
- [ ] UI zeigt Turn-Status korrekt an
- [ ] Server-Rejections für endTurn werden korrekt gehandhabt
- [ ] 82+ XCTest passieren
- [ ] 135+ CLI-Prüfungen passieren
- [ ] Alle E2E-Proben erfolgreich
- [ ] `phase85-multiplayer-turn-gating-plan.md` dokumentiert Ergebnisse
- [ ] Code in `main` Branch gemerged

## Zeitplan

| Task | Dauer | Verantwortlich |
|------|-------|----------------|
| Design des E2E-Harness | 4 Stunden | Entwickler |
| Implementierung Multiplayer-Harness | 8 Stunden | Entwickler |
| UI-Indikatoren implementieren | 4 Stunden | Entwickler |
| Server-Rejection-Handling | 4 Stunden | Entwickler |
| Unit-Tests schreiben | 4 Stunden | Entwickler |
| Integration in e2e-java-server.sh | 2 Stunden | Entwickler |
| Java-Server-Validierung | 8 Stunden | Entwickler |
| Manuelle Tests | 4 Stunden | Entwickler |
| Dokumentation | 2 Stunden | Entwickler |
| **Gesamt** | **40 Stunden** | **2–3 Tage** |

## Abhängigkeiten

- Keine spezifischen Abhängigkeiten von vorherigen Phasen (Core Gameplay Actions bereits implementiert)
- Java-Server-Docker-Image muss verfügbar sein
- `FreeColProtocolCLI` muss für parallele Instanzen fähig sein

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | Multiplayer-Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Multiplayer-E2E-Logik |
| `Sources/FreeColProtocolCLI/MultiplayerE2EHarness.swift` | Neu | E2E-Harness |
| `Sources/FreeColApp/GameState.swift` | Modifikation | Server-Rejection-Handling |
| `Sources/FreeColApp/GameView.swift` oder `StatusBarView.swift` | Neu/Modifikation | Turn-Status UI |
| `Tests/FreeColProtocolTests/FreeColProtocolTests.swift` | Erweiterung | Neue Tests |
| `Docs/Plans/phase85-multiplayer-turn-gating-plan.md` | Neu | Dieser Plan |
| `Docs/Plans/plans.md` | Modifikation | Phase 85 hinzufügen |

## Verwandte Dokumente

- `Docs/Plans/core-gameplay-actions-plan.md` (Turn-Gating Basis)
- `Docs/Plans/phase62-java-server-e2e-plan.md` (E2E-Proben Struktur)
- `Docs/Plans/phase63-gameplay-e2e-plan.md` (Gameplay-Probe Referenz)
- `Sources/FreeColApp/GameState.swift` (Implementierung)
