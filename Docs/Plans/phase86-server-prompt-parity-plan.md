# Phase 86 — Server Prompt Parity

## Ziel

Vollständige Implementierung und Validierung aller Server-Prompts, die eine Benutzerinteraktion erfordern. Der Client muss alle Synchronisations-Prompts des Java-Servers korrekt anzeigen, Benutzereingaben sammeln und die passenden Reply-Nachrichten senden.

## Kontext

### Aktueller Stand

Die folgende Tabelle zeigt den Implementierungsstatus der wichtigsten Server-Prompts:

| Prompt-Typ | Message-Tag | Java-Side | Swift-Side | UI | E2E-Test |
|------------|-------------|-----------|------------|----|----------|
| Monarch Action | `monarchAction` | ✅ | ⚠️ Teilweise | ⚠️ Teilweise | ❌ |
| First Contact | `firstContact` | ✅ | ⚠️ Teilweise | ❌ | ❌ |
| New Land Name | `newLandName` | ✅ | ✅ | ✅ | ⚠️ Indirekt |
| New Region Name | `newRegionName` | ✅ | ✅ | ✅ | ⚠️ Indirekt |
| Indian Demand | `indianDemand` | ✅ | ❌ | ❌ | ❌ |
| Close | `close` | ✅ | ✅ | ✅ | ✅ |
| High Scores | `highScores` | ✅ | ✅ | ✅ | ✅ |
| Nation Summary | `nationSummary` | ✅ | ✅ | ✅ | ✅ |

**Legende:** ✅ Vollständig, ⚠️ Teilweise, ❌ Nicht implementiert

### Java-Server-Verhalten

Alle Server-Prompts folgen dem **Question/Reply-Muster**:

1. Server sendet: `<question networkReplyId="N"><monarchAction action="taxIncrease" .../></question>`
2. Client muss antworten: `<reply networkReplyId="N"><monarchAction action="accept"/></reply>`
3. Server verarbeitet die Antwort und sendet ggf. weitere Updates

### Offene Lücken

1. **`monarchAction`:** Teilweise implementiert, aber nicht vollständig getestet
2. **`firstContact`:** Message-Handler existiert, aber keine UI für Native-Kontakt-Dialog
3. **`indianDemand`:** Kein Handler, keine UI
4. **Fehlende User-Facing Fehler:** Server-Rejections werden nicht immer benutzerfreundlich angezeigt

## Umsetzung

### 1. Monarch Action Prompt

**Ziel:** Vollständige Unterstützung für alle Monarch-Action-Typen.

#### Message-Struktur (Java Referenz)

```xml
<!-- Server → Client: Question -->
<question networkReplyId="42">
  <monarchAction action="taxIncrease" monarch="monarch.king.georgeI" tax="25" ...>
    <stringTemplate id="monarch.raiseTax" ...>
      <stringTemplateEntry key="%monarch%" value="King George I"/>
      <stringTemplateEntry key="%amount%" value="25"/>
    </stringTemplate>
  </monarchAction>
</question>

<!-- Client → Server: Reply -->
<reply networkReplyId="42">
  <monarchAction action="accept" />
</reply>
<!-- oder -->
<reply networkReplyId="42">
  <monarchAction action="reject" />
</reply>
```

#### Implementierung

**GameState.swift:**

```swift
// Handler für MonarchAction
func handleMonarchAction(_ message: MonarchActionMessage, networkReplyId: Int) {
    // Speichere den aktuellen Monarch-Action-Kontext
    pendingMonarchAction = MonarchActionContext(
        message: message,
        networkReplyId: networkReplyId
    )
    
    // Berechne User-Facing Nachricht
    let promptText = formatMonarchActionPrompt(message)
    let title = "Monarch-Aktion"
    
    // Zeige Dialog an
    showMonarchActionDialog = true
    monarchActionTitle = title
    monarchActionMessage = promptText
}

struct MonarchActionContext {
    let message: MonarchActionMessage
    let networkReplyId: Int
}

private func formatMonarchActionPrompt(_ message: MonarchActionMessage) -> String {
    // Nutze stringTemplate falls vorhanden
    if let template = message.stringTemplate {
        return template.resolvedText
    }
    
    // Fallback: Direkte Übersetzungen
    switch message.action {
    case "taxIncrease":
        return "Der Monarch möchte die Steuern auf \(message.tax ?? "?")% erhöhen."
    case "taxDecrease":
        return "Der Monarch bietet an, die Steuern auf \(message.tax ?? "?")% zu senken."
    case "addToArmy":
        return "Der Monarch fordert \(message.gold ?? "?") Gold für die Armee."
    case "addToNavy":
        return "Der Monarch fordert \(message.gold ?? "?") Gold für die Marine."
    case "bell":
        return "Der Monarch verkündet eine neue Freiheit: \(message.bell ?? "?")"
    default:
        return "Der Monarch hat eine Aktion: \(message.action)"
    }
}

// Benutzer-Antwort Handler
func monarchActionAccept() {
    guard let context = pendingMonarchAction else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: MonarchActionMessage(action: "accept")
    )
    
    client.send(reply)
    pendingMonarchAction = nil
    showMonarchActionDialog = false
}

func monarchActionReject() {
    guard let context = pendingMonarchAction else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: MonarchActionMessage(action: "reject")
    )
    
    client.send(reply)
    pendingMonarchAction = nil
    showMonarchActionDialog = false
}
```

**SwiftUI Dialog:**

```swift
// MonarchActionDialog.swift
struct MonarchActionDialog: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 20) {
            Text(gameState.monarchActionTitle)
                .font(.title2)
                .padding(.bottom, 4)
            
            Text(gameState.monarchActionMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Ablehnen") {
                    gameState.monarchActionReject()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Akzeptieren") {
                    gameState.monarchActionAccept()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .presentationDetents([.sizeThatFits])
    }
}

// In GameView.swift
.sheet(isPresented: $gameState.showMonarchActionDialog) {
    MonarchActionDialog()
        .environmentObject(gameState)
}
```

#### E2E-Test

```swift
// In FreeColProtocolCLI
func testMonarchActionPrompt() async throws {
    // Warte auf monarchAction Question
    let (question, replyId) = try await client.awaitQuestion(ofType: MonarchActionMessage.self)
    
    // Verifiziere Message-Inhalt
    assert(question.action == "taxIncrease" || question.action == "taxDecrease")
    
    // Sende Accept-Reply
    let reply = ReplyMessage(
        networkReplyId: replyId,
        content: MonarchActionMessage(action: "accept")
    )
    try await client.sendAndAwaitReply(reply)
    
    // Warte auf Bestätigung oder nächste Message
    // Der Server sendet ggf. weitere Updates
}
```

### 2. First Contact Prompt

**Ziel:** Native-Kontakt-Dialog mit Akzeptieren/Ablehnen-Optionen.

#### Message-Struktur

```xml
<!-- Server → Client -->
<question networkReplyId="43">
  <firstContact player="player-1" other="player-native" tile="tile-100" camps="true">
    <stringTemplate id="firstContact.nation" .../>
  </firstContact>
</question>

<!-- Client → Server: Reply -->
<reply networkReplyId="43">
  <firstContact result="true" />
</reply>
<!-- oder -->
<reply networkReplyId="43">
  <firstContact result="false" />
</reply>
```

#### Implementierung

**GameState.swift:**

```swift
func handleFirstContact(_ message: FirstContactMessage, networkReplyId: Int) {
    pendingFirstContact = FirstContactContext(
        message: message,
        networkReplyId: networkReplyId
    )
    
    // Ermittele Native-Nation-Name
    let nativeNationName = gameState.player(for: message.other)?.nation?.name 
        ?? message.other
    let ourPlayerName = gameState.player(for: message.player)?.name 
        ?? "Du"
    
    let promptText = "\(ourPlayerName) hat zum ersten Mal Kontakt mit \(nativeNationName) aufgenommen. Soll die diplomatische Beziehung hergestellt werden?"
    
    showFirstContactDialog = true
    firstContactMessage = promptText
}

struct FirstContactContext {
    let message: FirstContactMessage
    let networkReplyId: Int
}

func firstContactAccept() {
    guard let context = pendingFirstContact else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: FirstContactMessage(result: "true")
    )
    
    client.send(reply)
    pendingFirstContact = nil
    showFirstContactDialog = false
}

func firstContactReject() {
    guard let context = pendingFirstContact else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: FirstContactMessage(result: "false")
    )
    
    client.send(reply)
    pendingFirstContact = nil
    showFirstContactDialog = false
}
```

**SwiftUI Dialog:**

```swift
struct FirstContactDialog: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Erster Kontakt")
                .font(.title2)
            
            Text(gameState.firstContactMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Ablehnen") {
                    gameState.firstContactReject()
                }
                
                Button("Akzeptieren") {
                    gameState.firstContactAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
    }
}
```

### 3. Indian Demand Prompt

**Ziel:** Tribute-Aufforderung von Natives mit Akzeptieren/Ablehnen.

#### Message-Struktur

```xml
<!-- Server → Client -->
<question networkReplyId="44">
  <indianDemand unit="unit-1" colony="colony-1" type="gold" amount="500" />
</question>

<!-- Client → Server: Reply -->
<reply networkReplyId="44">
  <indianDemand result="indian_demand_accept" />
</reply>
<!-- oder -->
<reply networkReplyId="44">
  <indianDemand result="indian_demand_reject" />
</reply>
```

#### Implementierung

**GameState.swift:**

```swift
func handleIndianDemand(_ message: IndianDemandMessage, networkReplyId: Int) {
    pendingIndianDemand = IndianDemandContext(
        message: message,
        networkReplyId: networkReplyId
    )
    
    let unitName = gameState.unit(for: message.unit)?.name ?? "eine Einheit"
    let colonyName = gameState.colony(for: message.colony)?.name ?? "eine Kolonie"
    let amount = message.amount ?? "?"
    let type = message.type ?? "Gold"
    
    let promptText = "Die Native verlangen \(amount) \(type) von \(colonyName) als Tribut für \(unitName)."
    
    showIndianDemandDialog = true
    indianDemandMessage = promptText
}

struct IndianDemandContext {
    let message: IndianDemandMessage
    let networkReplyId: Int
}

func indianDemandAccept() {
    guard let context = pendingIndianDemand else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: IndianDemandMessage(result: "indian_demand_accept")
    )
    
    client.send(reply)
    pendingIndianDemand = nil
    showIndianDemandDialog = false
}

func indianDemandReject() {
    guard let context = pendingIndianDemand else { return }
    
    let reply = ReplyMessage(
        networkReplyId: context.networkReplyId,
        content: IndianDemandMessage(result: "indian_demand_reject")
    )
    
    client.send(reply)
    pendingIndianDemand = nil
    showIndianDemandDialog = false
}
```

**SwiftUI Dialog:**

```swift
struct IndianDemandDialog: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tribut-Forderung")
                .font(.title2)
            
            Text(gameState.indianDemandMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Warnung: Ablehnen kann zu Angriff führen!")
                .font(.caption)
                .foregroundColor(.red)
            
            HStack(spacing: 20) {
                Button("Ablehnen") {
                    gameState.indianDemandReject()
                }
                
                Button("Akzeptieren") {
                    gameState.indianDemandAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
    }
}
```

### 4. Generic Question/Reply Handling Verbesserung

**Ziel:** Robustes Handling für alle unbekannten Question-Typen.

#### Implementierung

**GameState.swift:**

```swift
// ZENTRALER Question-Handler
func handleQuestionMessage(_ message: QuestionMessage) {
    let innerMessage = message.content
    let replyId = message.networkReplyId
    
    // Routing basierend auf innerem Message-Typ
    switch innerMessage {
    case let m as MonarchActionMessage:
        handleMonarchAction(m, networkReplyId: replyId)
    
    case let m as FirstContactMessage:
        handleFirstContact(m, networkReplyId: replyId)
    
    case let m as IndianDemandMessage:
        handleIndianDemand(m, networkReplyId: replyId)
    
    case let m as NewLandNameMessage:
        handleNewLandName(m, networkReplyId: replyId)
    
    case let m as NewRegionNameMessage:
        handleNewRegionName(m, networkReplyId: replyId)
    
    case let m as DiplomacyMessage:
        // Für Phase 86: Grundimplementierung
        handleDiplomacyPrompt(m, networkReplyId: replyId)
    
    default:
        // Logge unbekannten Typ für Debugging
        logger.warning("Unhandled question with inner message: \(type(of: innerMessage))")
        
        // Fallback: Automatisches Accept für Tests
        // (NUR für Entwicklung, nicht für Produktion!)
        #if DEBUG
        if autoAcceptQuestionsInDebug {
            let reply = ReplyMessage(
                networkReplyId: replyId,
                content: innerMessage
            )
            client.send(reply)
        }
        #endif
    }
}
```

### 5. E2E-Tests für alle Prompts

**Ziel:** Automatisierte Tests gegen den Java-Server.

#### Test-Szenarien

| Prompt | Test-Szenario | Erwartetes Ergebnis |
|--------|---------------|---------------------|
| monarchAction | Server sendet taxIncrease | Client zeigt Dialog, Benutzer akzeptiert, Server bestätigt |
| monarchAction | Server sendet taxDecrease | Client zeigt Dialog, Benutzer lehnt ab, Server bestätigt |
| firstContact | Unit trifft auf Native | Client zeigt Dialog, Benutzer akzeptiert, Stance wird PEACE |
| firstContact | Unit trifft auf Native | Client zeigt Dialog, Benutzer lehnt ab, Stance wird WAR |
| indianDemand | Native fordern Tribut | Client zeigt Dialog, Benutzer akzeptiert, Gold wird abgezogen |
| indianDemand | Native fordern Tribut | Client zeigt Dialog, Benutzer lehnt ab, Einheit wird angegriffen |

#### CLI-Test-Implementierung

```swift
// In FreeColProtocolCLI

func testMonarchActionAccept() async throws {
    // Warte auf monarchAction
    let (question, replyId) = try await client.awaitQuestion(ofType: MonarchActionMessage.self)
    
    // Sende Accept
    let reply = ReplyMessage(
        networkReplyId: replyId,
        content: MonarchActionMessage(action: "accept")
    )
    let response = try await client.sendAndAwaitReply(reply)
    
    // Verifiziere keine Error
    assert(!response.containsError, "Monarch action accept failed")
}

func testFirstContactAccept() async throws {
    // Warte auf firstContact
    let (question, replyId) = try await client.awaitQuestion(ofType: FirstContactMessage.self)
    
    // Sende Accept
    let reply = ReplyMessage(
        networkReplyId: replyId,
        content: FirstContactMessage(result: "true")
    )
    let response = try await client.sendAndAwaitReply(reply)
    
    // Warte auf setStance Message
    let stanceMessage = try await client.awaitMessage(ofType: SetStanceMessage.self)
    assert(stanceMessage.stance == "PEACE", "Expected PEACE stance after accept")
}

func testIndianDemandAccept() async throws {
    // Warte auf indianDemand
    let (question, replyId) = try await client.awaitQuestion(ofType: IndianDemandMessage.self)
    
    // Merke aktuelles Gold
    let initialGold = client.gameState.localPlayer?.gold ?? 0
    let demandAmount = Int(question.amount ?? "0") ?? 0
    
    // Sende Accept
    let reply = ReplyMessage(
        networkReplyId: replyId,
        content: IndianDemandMessage(result: "indian_demand_accept")
    )
    try await client.sendAndAwaitReply(reply)
    
    // Warte auf Partial-Update für Gold
    let goldUpdate = try await client.awaitPartialUpdate(for: client.gameState.localPlayerId)
    let newGold = Int(goldUpdate.attributes["gold"] ?? "0") ?? 0
    
    // Verifiziere Gold-Abzug
    assert(newGold == initialGold - demandAmount, "Gold not deducted correctly")
}
```

#### e2e-java-server.sh Integration

```bash
# Nach der Trade-Route-Probe
echo "==> Server Prompt Parity probe (monarchAction, firstContact, indianDemand)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_PROMPT_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

## Validierung

### 1. Unit Tests

```swift
// Test: MonarchAction Handler
func testMonarchActionHandler() {
    let message = MonarchActionMessage(action: "taxIncrease", tax: "25")
    gameState.handleMonarchAction(message, networkReplyId: 1)
    
    XCTAssertTrue(gameState.showMonarchActionDialog)
    XCTAssertNotNil(gameState.pendingMonarchAction)
    XCTAssert(gameState.monarchActionMessage.contains("Steuern"))
}

// Test: FirstContact Handler
func testFirstContactHandler() {
    let message = FirstContactMessage(
        player: "player-1",
        other: "player-native",
        tile: "tile-100",
        camps: "true"
    )
    gameState.handleFirstContact(message, networkReplyId: 1)
    
    XCTAssertTrue(gameState.showFirstContactDialog)
    XCTAssertNotNil(gameState.pendingFirstContact)
}

// Test: IndianDemand Handler
func testIndianDemandHandler() {
    let message = IndianDemandMessage(
        unit: "unit-1",
        colony: "colony-1",
        type: "gold",
        amount: "500"
    )
    gameState.handleIndianDemand(message, networkReplyId: 1)
    
    XCTAssertTrue(gameState.showIndianDemandDialog)
    XCTAssertNotNil(gameState.pendingIndianDemand)
    XCTAssert(gameState.indianDemandMessage.contains("500"))
}

// Test: Reply Generation
func testMonarchActionAcceptReply() {
    gameState.pendingMonarchAction = MonarchActionContext(
        message: MonarchActionMessage(action: "taxIncrease"),
        networkReplyId: 42
    )
    
    // Simuliere Benutzer-Klick auf Akzeptieren
    gameState.monarchActionAccept()
    
    // Sollte Reply gesendet haben
    // (Mock Client für Test Zwecke)
    XCTAssertNil(gameState.pendingMonarchAction)
    XCTAssertFalse(gameState.showMonarchActionDialog)
}
```

### 2. CLI Integration Tests

```bash
swift run FreeColProtocolCLI  # Ziel: 135+ Prüfungen
```

### 3. E2E Tests gegen Java-Server

```bash
# Einzelne Prompt-Probe
REAL_SERVER_PROMPT_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI

# Vollständige Suite
Tools/e2e-java-server.sh  # Sollte Prompt-Probe enthalten
```

### 4. Manuelle Tests

- [ ] Starte Spiel gegen Java-Server
- [ ] Bewege Einheit, bis Monarch-Action ausgelöst wird
- [ ] Dialog wird angezeigt mit korrektem Text
- [ ] Akzeptieren: Aktion wird ausgeführt
- [ ] Ablehnen: Aktion wird abgelehnt
- [ ] Teste First Contact mit Native
- [ ] Teste Indian Demand

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| monarchAction Prompt funktioniert | Unit-Tests + E2E | ⬜ |
| firstContact Prompt funktioniert | Unit-Tests + E2E | ⬜ |
| indianDemand Prompt funktioniert | Unit-Tests + E2E | ⬜ |
| Alle Dialoge zeigen korrekte Nachrichten | Manuelle Tests | ⬜ |
| Server-Replies werden korrekt gesendet | E2E-Tests | ⬜ |
| UI reagiert auf Benutzerinteraktion | Manuelle Tests | ⬜ |
| Alle bestehenden Tests passieren | 85+ XCTest, 135+ CLI | ⬜ |
| Keine Regressionen | Alle E2E-Proben passieren | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Java-Server sendet unerwartete Message-Attribute | Mittel | Hoch | Flexibles Parsing, Fallbacks |
| StringTemplate-Resolution fehlschlägt | Niedrig | Mittel | Fallback auf direkte Attribute |
| Dialoge blockieren Spiel-State | Niedrig | Hoch | Non-modal Dialoge oder async Handling |
| Race-Condition bei mehreren Prompts | Niedrig | Hoch | Queue für ausstehende Prompts |
| Benutzer schließt Dialog ohne Antwort | Mittel | Mittel | Timeout und auto-reject |
| Lokale Strings fehlen | Hoch | Mittel | English Fallback implementieren |

## Definition of Done

- [ ] monarchAction Prompt vollständig implementiert und getestet
- [ ] firstContact Prompt vollständig implementiert und getestet
- [ ] indianDemand Prompt vollständig implementiert und getestet
- [ ] Generisches Question/Reply-Handling verbessert
- [ ] 85+ XCTest passieren
- [ ] 135+ CLI-Prüfungen passieren
- [ ] Alle E2E-Proben erfolgreich (inkl. Prompt-Probe)
- [ ] `phase86-server-prompt-parity-plan.md` dokumentiert Ergebnisse
- [ ] Code in `main` Branch gemerged

## Zeitplan

| Task | Dauer | Verantwortlich |
|------|-------|----------------|
| monarchAction Implementierung | 6 Stunden | Entwickler |
| firstContact Implementierung | 4 Stunden | Entwickler |
| indianDemand Implementierung | 4 Stunden | Entwickler |
| Generic Question Handler | 2 Stunden | Entwickler |
| Unit-Tests schreiben | 4 Stunden | Entwickler |
| E2E-Tests implementieren | 4 Stunden | Entwickler |
| Integration in e2e-java-server.sh | 1 Stunde | Entwickler |
| UI-Dialoge polieren | 4 Stunden | Entwickler |
| Java-Server-Validierung | 6 Stunden | Entwickler |
| Manuelle Tests | 4 Stunden | Entwickler |
| Dokumentation | 2 Stunden | Entwickler |
| **Gesamt** | **37 Stunden** | **2 Tage** |

## Abhängigkeiten

- Keine spezifischen Abhängigkeiten (alle Messages bereits generiert)
- Java-Server-Docker-Image muss verfügbar sein

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | Prompt-Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Prompt-E2E-Logik |
| `Sources/Novaloria/GameState.swift` | Modifikation | Prompt-Handler |
| `Sources/Novaloria/MonarchActionDialog.swift` | Neu | Monarch-Action-Dialog |
| `Sources/Novaloria/FirstContactDialog.swift` | Neu | First-Contact-Dialog |
| `Sources/Novaloria/IndianDemandDialog.swift` | Neu | Indian-Demand-Dialog |
| `Tests/FreeColProtocolTests/FreeColProtocolTests.swift` | Erweiterung | Neue Tests |
| `Docs/Plans/phase86-server-prompt-parity-plan.md` | Neu | Dieser Plan |
| `Docs/Plans/plans.md` | Modifikation | Phase 86 hinzufügen |

## Verwandte Dokumente

- `Docs/Plans/core-gameplay-actions-plan.md` (Message-Handling Basis)
- `Docs/Plans/phase42-server-decision-dialogs-plan.md` (Dialog-Struktur)
- `Docs/Plans/phase43-server-decision-payload-contract-plan.md` (Payload-Handling)
- `Docs/Plans/phase44-server-prompt-dialog-parity-plan.md` (Prompt-Parität)
- `Docs/protocol.md` (Message-Katalog)
- `Sources/FreeColProtocol/Messages/MonarchActionMessage.swift`
- `Sources/FreeColProtocol/Messages/FirstContactMessage.swift`
- `Sources/FreeColProtocol/Messages/IndianDemandMessage.swift`
