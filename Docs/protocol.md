# FreeCol TCP/XML Protocol Reference

## Transport Layer

| Property | Value |
|---|---|
| Transport | Plain TCP (no TLS) |
| Default Port | 3541 |
| Encoding | UTF-8 |
| Framing | Newline-delimited (`\n`, `0x0A`) — one complete XML element per line |
| Max line size | `BufferedReader` default (8 KB), but messages can be large (e.g. login carries the full game) |

### Wire Format

Each message is a single XML element serialized as a one-liner and terminated with `\n`:

```
<tag attr1="val1" attr2="val2"/>\n
<tag attr1="val1"><child/></tag>\n
```

- No XML declaration (`<?xml?>`)
- No length prefix
- No pretty-printing — compact XML on a single line
- Self-closing tags for elements without children

### Reference Implementation (Java)

- Sending: `Connection.java` line 476–487 — `message.toXML(this.xw)` + `writeCharacters('\n')` + `flush()`
- Receiving: `Connection.java` line 394–409 — `BufferedReader.readLine()` → `FreeColXMLReader(new StringReader(line))` → `xr.nextTag()` → return tag name
- Writer: `FreeColXMLWriter` wraps `XMLStreamWriter` over a `StringWriter`, not indented
- Reader: `FreeColXMLReader` wraps `XMLStreamReader` (StAX)

---

## Message Hierarchy

All messages reside in `net.sf.freecol.common.networking`. The Java class hierarchy is:

```
Message (abstract)
  |
  +-- TrivialMessage (abstract) -- tag only, no attributes, no children
  |     +-- [tag-only messages]
  |
  +-- AttributeMessage (abstract) -- tag + key=value attributes
  |     +-- WrapperMessage (abstract) -- wraps another message + networkReplyId
  |     |     +-- QuestionMessage      TAG="question"
  |     |     +-- ReplyMessage         TAG="reply"
  |     +-- MultipleMessage            TAG="multiple"
  |     +-- RemoveMessage              TAG="remove"
  |     +-- PartialMessage             TAG="partial"
  |     +-- SetCurrentPlayerMessage    TAG="setCurrentPlayer"
  |     +-- NewTurnMessage             TAG="newTurn"
  |     +-- GameStateMessage           TAG="gameState"
  |     +-- ServerInfoMessage          TAG="serverInfo"
  |     +-- ServerListMessage          TAG="serverList"
  |     +-- VacantPlayersMessage       TAG="vacantPlayers"
  |     +-- ChatMessage                TAG="chat"
  |     +-- SetStanceMessage           TAG="setStance"
  |     +-- SetColorMessage            TAG="setColor"
  |     +-- LogoutMessage              TAG="logout"
  |     +-- AttributeMessage           TAG="attribute"
  |     +-- [many more...]
  |
  +-- ObjectMessage (abstract) -- tag + attributes + child FreeColObject list
        +-- LoginMessage               TAG="login"
        +-- ErrorMessage               TAG="error"
        +-- UpdateMessage              TAG="update"
        +-- FeatureChangeMessage       TAG="featureChange"
        +-- AddPlayerMessage           TAG="addPlayer"
        +-- [many action messages...]
```

### Event presentation (macOS client)

Server decisions (including founding fathers, region/land naming, first contact,
monarch actions, native trade, and diplomacy) appear as overlays over the map.
The map keeps its size and position while a decision is open. Dialog content
scrolls when necessary, and map clicks and gameplay keyboard shortcuts are
blocked until the decision is resolved. Event notifications also appear inside
the map area, behind any active decision.

### Message Dispatch (Java)

Messages are deserialized by reflection. Given a tag-name `foo`, the system looks up `net.sf.freecol.common.networking.FooMessage`, finds its `(Game, FreeColXMLReader)` constructor, and calls it. The mapping is cached in a static `builders` map (`Message.java:63`).

Each concrete message must implement:

| Method | Purpose |
|---|---|
| `getType()` | Returns the XML tag name |
| `clientHandler(FreeColClient)` | Client-side handling |
| `serverHandler(FreeColServer, Connection)` | Server-side handling, returns `ChangeSet` |
| `aiHandler(FreeColServer, AIPlayer)` | AI player handling |
| `getPriority()` | Ordering within a `MultipleMessage` |
| `currentPlayerMessage()` | Whether only the current player can send this |

---

## Complete Message Catalogue

### Connection & Session Management

| Message | Tag | Direction | Content |
|---|---|---|---|
| `LoginMessage` | `login` | C→S, S→C | Attributes: `userName`, `nationId`, `version`, `singlePlayer`, `currentPlayer`, `state`. Children: full `<game>` element on server reply |
| `LogoutMessage` | `logout` | C→S, S→C | Attribute: `reason` (QUIT, END_GAME, etc.) |
| `DisconnectMessage` | `disconnect` | C→S, S→C | No attributes. Signals TCP disconnect |
| `ReconnectMessage` | `reconnect` | S→C | No attributes. Tells client to reconnect |
| `GameStateMessage` | `gameState` | S→C | Attribute: `state` (PRE_GAME, IN_GAME, END_GAME) |
| `VacantPlayersMessage` | `vacantPlayers` | S→C | Children: `<player>` entries for available slots |
| `ConnectionVerificationMessage` | `connectionVerification` | Meta-server | Meta-server handshake |

### Game Lifecycle

| Message | Tag | Direction | Content |
|---|---|---|---|
| `StartGameMessage` | `startGame` | S→C | No attributes. Signals game start |
| `RequestLaunchMessage` | `requestLaunch` | C→S | No attributes. Client asks to start |
| `GameEndedMessage` | `gameEnded` | S→C | Attribute: `winner` player ID |
| `NewTurnMessage` | `newTurn` | S→C | Attribute: `turn` (integer) |
| `SetCurrentPlayerMessage` | `setCurrentPlayer` | S→C | Attribute: `player` → player ID |

### State Updates (Server → Client)

| Message | Tag | Content |
|---|---|---|
| `UpdateMessage` | `update` | Children: one or more full `FreeColGameObject` serializations |
| `PartialMessage` | `partial` | Attributes: partial field updates on an object (e.g. `movesLeft="2"`, `location="tile-5"`) |
| `RemoveMessage` | `remove` | Attributes: lists of object IDs to remove (`divert`, `array_0`..`array_N`) |
| `FeatureChangeMessage` | `featureChange` | Attributes: `player`, `add` (boolean). Children: ability, modifier, history, model message |
| `AddPlayerMessage` | `addPlayer` | Children: full `<player>` element |
| `SetStanceMessage` | `setStance` | Attributes: `stance`, `source`, `target` (player IDs) |
| `MultipleMessage` | `multiple` | Children: zero or more messages. Wrapper for batch updates |

### Client Actions (Client → Server, via Question/Reply)

These are sent as `<question>` and the server replies with `<reply>`. All contain relevant object IDs as attributes.

#### Unit Actions
| Message | Tag | Key Attributes |
|---|---|---|
| `MoveMessage` | `move` | `unit`, `direction` |
| `MoveToMessage` | `moveTo` | `unit`, `destination` |
| `AttackMessage` | `attack` | `unit`, `direction` |
| `AttackRangedMessage` | `attackRanged` | `unit`, `direction` |
| `EmbarkMessage` | `embark` | `unit`, `carrier` |
| `DisembarkMessage` | `disembark` | `unit` |
| `BuildColonyMessage` | `buildColony` | `unit`, `name` |
| `ChangeStateMessage` | `changeState` | `unit`, `state` |
| `ChangeWorkTypeMessage` | `changeWorkType` | `unit`, `workType` |
| `ChangeWorkImprovementTypeMessage` | `changeWorkImprovementType` | `unit`, `improvementType` |
| `WorkMessage` | `work` | `unit`, `workLocation` |
| `LoadGoodsMessage` | `loadGoods` | `unit`, `goodsType`, `amount` |
| `UnloadGoodsMessage` | `unloadGoods` | `unit`, `goodsType`, `amount` |
| `DisbandUnitMessage` | `disbandUnit` | `unit` |
| `ClearSpecialityMessage` | `clearSpeciality` | `unit` |
| `EquipForRoleMessage` | `equipForRole` | `unit`, `role` |
| `SetDestinationMessage` | `setDestination` | `unit`, `destination` |
| `CashInTreasureTrainMessage` | `cashInTreasureTrain` | `unit` |

#### Colony Actions
| Message | Tag | Key Attributes |
|---|---|---|
| `SetBuildQueueMessage` | `setBuildQueue` | `colony`, children: `<buildable>` elements |
| `AbandonColonyMessage` | `abandonColony` | `colony` |
| `JoinColonyMessage` | `joinColony` | `unit`, `colony` |
| `SetGoodsLevelsMessage` | `setGoodsLevels` | `colony`, children: `<goodsLevel>` elements |
| `PayForBuildingMessage` | `payForBuilding` | `colony`, `buildable` |
| `PutOutsideColonyMessage` | `putOutsideColony` | `unit` |

#### Europe Actions
| Message | Tag | Key Attributes |
|---|---|---|
| `TrainUnitInEuropeMessage` | `trainUnitInEurope` | `unitType` |
| `EmigrateUnitMessage` | `emigrateUnit` | `slot` |
| `PayArrearsMessage` | `payArrears` | `unit`, `goodsType` |
| `FountainOfYouthMessage` | `fountainOfYouth` | S→C notification: `migrants` (reply via `emigrateUnit`) |

#### Diplomacy & Natives
| Message | Tag | Key Attributes |
|---|---|---|
| `DiplomacyMessage` | `diplomacy` | `ourId`, `otherId`; child `<diplomaticTrade context= sender= recipient= status= version=>` with clause children (`goldTradeItem`, `goodsTradeItem`, `colonyTradeItem`, `unitTradeItem`, `stanceTradeItem`, `inciteTradeItem`) |
| `FirstContactMessage` | `firstContact` | `player`, `other`, `tile`, `camps`; reply adds `result` (`"true"`/`"false"`) |
| `IndianDemandMessage` | `indianDemand` | `unit`, `colony`, `type`, `amount`; reply adds `result` (`indian_demand_accept`/`indian_demand_reject`) |
| `NativeTradeMessage` | `nativeTrade` | `action` (`OPEN`/`CLOSE`/`BUY`/`SELL`/`GIFT` + `ACK_*`/`NAK_*`); child `<nativeTrade unit= settlement= buy= sell= gift= count=>` with `<settlementToUnit>`/`<unitToSettlement>` wrappers of `<nativeTradeItem price= haggleCount=><goods .../></nativeTradeItem>` |
| `NativeGiftMessage` | `nativeGift` | `unit`, `settlement`, children: `<goods>` |
| `MissionaryMessage` | `missionary` | `unit`, `settlement`, `action` |
| `ScoutIndianSettlementMessage` | `scoutIndianSettlement` | `unit`, `settlement` |
| `ScoutSpeakToChiefMessage` | `scoutSpeakToChief` | `unit`, `settlement` |
| `LearnSkillMessage` | `learnSkill` | `unit`, `settlement` |
| `AskSkillMessage` | `askSkill` | `unit`, `settlement` |
| `InciteMessage` | `incite` | `unit`, `settlement`, `enemy` |
| `DeliverGiftMessage` | `deliverGift` | `unit`, `settlement`, children: `<goods>` |
| `ClaimLandMessage` | `claimLand` | `settlement`, `tile` |
| `DemandTributeMessage` | `demandTribute` | `unit`, `settlement` |
| `SpySettlementMessage` | `spySettlement` | `unit`, `settlement` |
| `DeclareIndependenceMessage` | `declareIndependence` | `nation`, `nationType` |

#### Pre-game
| Message | Tag | Key Attributes |
|---|---|---|
| `SetNationMessage` | `setNation` | `player`, `value` (nation ID) |
| `SetNationTypeMessage` | `setNationType` | `player`, `value` (nation type) |
| `ReadyMessage` | `ready` | `player`, `value` (boolean) |
| `SetColorMessage` | `setColor` | `player`, `value` (color) |
| `UpdateGameOptionsMessage` | `updateGameOptions` | Children: `<option>` elements |
| `UpdateMapGeneratorOptionsMessage` | `updateMapGeneratorOptions` | Children: `<option>` elements |
| `ChooseFoundingFatherMessage` | `chooseFoundingFather` | `foundingFather` |

#### Turn
| Message | Tag | Direction | Content |
|---|---|---|---|
| `EndTurnMessage` | `endTurn` | C→S | No attributes |
| `ContinueMessage` | `continue` | C→S, S→C | No attributes |

#### Animations
| Message | Tag | Key Attributes |
|---|---|---|
| `AnimateMoveMessage` | `animateMove` | `unit`, `newTile`, `oldTile` |
| `AnimateAttackMessage` | `animateAttack` | `attacker`, `defender`, `target`, `type` |

#### Miscellaneous
| Message | Tag | Key Attributes / Content |
|---|---|---|
| `ErrorMessage` | `error` | Attribute: `message`. Child: optional `<stringTemplate>` |
| `ChatMessage` | `chat` | `sender`, `message`, `private` (boolean) |
| `HighScoresMessage` | `highScores` | Children: `<highScore>` entries |
| `NationSummaryMessage` | `nationSummary` | `player`, children with summary data |
| `LootCargoMessage` | `lootCargo` | `winner`, `loser`, children: `<goods type= amount=>` |
| `MonarchActionMessage` | `monarchAction` | `action` (enum, down-cased), `monarch`, `tax`; reply adds `result` (`"true"`/`"false"`). S→C offer + C→S answer, current-player only |
| `NewLandNameMessage` | `newLandName` | `unit`, `newLandName` (inbound carries the default name) |
| `NewRegionNameMessage` | `newRegionName` | `region`, `tile`, `unit`, `newRegionName` (inbound carries the default name) |
| `CloseMessage` | `close` | `panel` (server closes a timed-out popup) |
| `NewTradeRouteMessage` | `newTradeRoute` | Children: `<tradeRoute>` |
| `UpdateTradeRouteMessage` | `updateTradeRoute` | Children: `<tradeRoute>` |
| `DeleteTradeRouteMessage` | `deleteTradeRoute` | `tradeRoute` |
| `AssignTradeRouteMessage` | `assignTradeRoute` | `unit`, `tradeRoute` |
| `SetCurrentStopMessage` | `setCurrentStop` | `unit`, `stop` |
| `RenameMessage` | `rename` | `object`, `value` |
| `SetAIMessage` | `setAI` | `player`, `ai` (boolean) |
| `SetAvailableMessage` | `setAvailable` | `player` |
| `AssignTeacherMessage` | `assignTeacher` | `student`, `teacher` |
| `RetireMessage` | `retire` | No attributes |
| `EnterRevengeModeMessage` | `enterRevengeMode` | No attributes |
| `DeclineMoundsMessage` | `declineMounds` | `unit` |
| `MonarchActionMessage` | `monarchAction` | `action`, `player` |
| `RegisterServerMessage` | `registerServer` | Meta-server |
| `AttributeMessage` | `attribute` | Generic mergeable key-value pair |
| `QuestionMessage` | `question` | `networkReplyId` + wrapped message |
| `ReplyMessage` | `reply` | `networkReplyId` + wrapped response |

---

## Handshake / Login Sequence

### Phase 1: TCP Connect

```
Client → Server: TCP connect to host:3541
```

### Phase 2: Server Sends Initial State

```
Server → Client: <gameState state="PRE_GAME"/>\n
Server → Client: <vacantPlayers>\n
                  <player nation="french" .../>\n
                  <player nation="english" .../>\n
                </vacantPlayers>\n
```

At this point the connection's handler is `UserConnectionHandler`, which only accepts `<login>` and `<disconnect>`.

### Phase 3: Client Sends Login

```
Client → Server: <question networkReplyId="1">\n
                   <login userName="Alice" nationId="french"\n
                          version="1.2.0+git"\n
                          singlePlayer="true"\n
                          currentPlayer="false"/>\n
                 </question>\n
```

### Phase 4: Server Validates & Replies

**PRE_GAME path** — new game:
```
Server → Client: <reply networkReplyId="1">\n
                   <login userName="Alice" nationId="french"\n
                          version="1.2.0+git" singlePlayer="true"\n
                          currentPlayer="true" state="PRE_GAME">\n
                     <game id="game-1" turnNumber="1">\n
                       <specification id="spec-1">...</specification>\n
                       <map id="map-1" width="60" height="40">...</map>\n
                       <player id="player-1" name="Alice" .../>\n
                       <player id="player-2" name="Bob" .../>\n
                     </game>\n
                   </login>\n
                 </reply>\n
```

**IN_GAME path** — rejoin mid-game:
Same format but `state="IN_GAME"`, and the game contains current turn state.

### Phase 5: Game Launch (PRE_GAME only)

When all players signal ready:
```
Client → Server: <requestLaunch/>\n
```

Server broadcasts:
```
Server → All: <startGame/>\n
Server → All: <addPlayer><player id="player-1" .../></addPlayer>\n
Server → All: <multiple>\n
                <update><game id="game-1" turnNumber="1">...</game></update>\n
                <setCurrentPlayer player="player-1"/>\n
              </multiple>\n
```

---

## Turn Sequence

### Step 1: Current player ends turn

```
Client → Server: <endTurn/>\n
```
This is a `currentPlayerMessage()` — only the active player can send it.

### Step 2: Server processes end of turn

Server calls `InGameController.endTurn()` which cycles through players.

For each player whose turn resolves:
```
Server → All: <multiple>\n
                <setStance .../>\n
                <partial id="player-1" gold="1420" .../>\n
                <featureChange player="player-1" add="true">\n
                  <ability id="model.ability.trade" value="true"/>\n
                </featureChange>\n
              </multiple>\n
```

### Step 3: New turn (when cycling back to first player)

```
Server → All: <newTurn turn="5"/>\n
```

### Step 4: Set next player

```
Server → All: <setCurrentPlayer player="player-2"/>\n
```

### Step 5: Monarch action (European players, if applicable)

```
Server → Player: <question networkReplyId="N">\n
                   <monarchAction action="taxIncrease" ...>\n
                     <stringTemplate ...>...</stringTemplate>\n
                   </monarchAction>\n
                 </question>\n
Player → Server: <reply networkReplyId="N">\n
                   <monarchAction action="accept"/>\n
                 </reply>\n
```

### Step 6: AI turns

AI players use `DummyConnection` (in-memory, no network). Their turns are processed by the server directly.

### During a Turn: Client Actions

All player actions follow the question/reply pattern:

```
Client → Server: <question networkReplyId="7">\n
                   <move unit="unit-3" direction="north"/>\n
                 </question>\n

Server → Client: <reply networkReplyId="7">\n
                   <multiple>\n
                     <partial id="unit-3" location="tile-5" movesLeft="2"/>\n
                     <animateMove unit="unit-3" newTile="tile-5" oldTile="tile-0"/>\n
                     <update><tile id="tile-5">...</tile></update>\n
                   </multiple>\n
                 </reply>\n
```

If the action fails:
```
Server → Client: <reply networkReplyId="7">\n
                   <error message="Unit cannot move there."/>\n
                 </reply>\n
```

---

## Question/Reply Mechanism

The protocol supports synchronous request/response using `question` and `reply` wrapper messages.

### Client sends a question:
```xml
<question networkReplyId="42">
  <move unit="unit-1" direction="north"/>
</question>
```

### Server replies:
```xml
<reply networkReplyId="42">
  <multiple>
    <update>...</update>
    <featureChange>...</featureChange>
  </multiple>
</reply>
```

### Flow (Java implementation):
1. Client assigns a monotonically increasing `networkReplyId` (int)
2. Client wraps the real message in a `QuestionMessage` (tag `<question>`) with the reply ID
3. Client registers a `NetworkReplyObject` for that ID, keyed in `waitingThreads` map
4. Client sends the question and blocks on `replyObject.getResponse(timeout)` (30s default)
5. Server receives `<question>`, reads inner message, spawns `QuestionThread` to handle it
6. Server wraps the response in a `ReplyMessage` (tag `<reply>`) with same `networkReplyId`
7. Client's `ReceivingThread` sees `<reply>`, extracts `networkReplyId`, finds the waiting `NetworkReplyObject`, calls `setResponse()` to unblock the caller

---

## ChangeSet — How the Server Sends State

The `ChangeSet` class is the **core server-to-client communication mechanism**. Every `serverHandler()` returns a `ChangeSet`.

### Change Types

| Change Type | Produces | Purpose |
|---|---|---|
| `ObjectChange` | `<update>` | Full serialized game objects |
| `PartialObjectChange` | `<partial>` | Field-level updates (movesLeft, gold, location) |
| `RemoveChange` | `<remove>` | Remove objects from client |
| `MessageChange` | *any message* | Arbitrary wrapper |
| `FeatureChange` | `<featureChange>` | Add/remove abilities, modifiers, model messages |
| `PlayerChange` | `<addPlayer>` | Add new players |
| `AttackChange` | `<animateAttack>` | Combat animation |
| `MoveChange` | `<animateMove>` | Movement animation |
| `StanceChange` | `<setStance>` | Diplomatic stance change |
| `AttributeChange` | `<attribute>` | Simple key=value |
| `SpyChange` | `<spySettlement>` | Spy result |

### Visibility Filtering

Each change has a `See` visibility:
- `See.all()` — visible to all players
- `See.perhaps()` — visible if player can see the objects
- `See.only(player)` — visible to one player only
- Combined: `.always(player)`, `.except(player)`, `.perhapsOnly(player)`

### Build Process

`ChangeSet.build(player)`:
1. Filters changes by player visibility
2. Converts eligible changes to `Message` objects
3. Sorts by priority (see below)
4. Merges compatible messages where possible
5. Wraps in `<multiple>`
6. If only 1 child, unwraps `<multiple>` → sends the single message directly
7. If 0 children, returns null (nothing to send)

### Priority Order

```
ANIMATION(0)  →  EARLY(1)  →  ADDPLAYER(4)  →  STANCE(5)
→  PARTIAL(9)  →  UPDATE(10)  →  NORMAL(15)  →  OWNED(20)
→  LATE(90)  →  LAST(99)  →  REMOVE(100)
```

Removes happen last so the client processes all updates before deleting objects.

---

## Message Examples

### Error Message
```xml
<error message="Unit can not move there."/>
```
With i18n template (more common on server):
```xml
<error>
  <stringTemplate id="template-1" template="server.userNameInUse">
    <stringTemplateEntry key="%name%" value="Alice"/>
  </stringTemplate>
</error>
```

### Chat Message
```xml
<chat sender="Alice" message="Hello!" private="false"/>
```

### Remove Message
```xml
<remove divert="tile-3" array_0="unit-7" array_1="unit-8"/>
```

### Partial Update
```xml
<partial id="unit-3" location="tile-5" movesLeft="2"/>
```

### New Turn
```xml
<newTurn turn="5"/>
```

### Set Current Player
```xml
<setCurrentPlayer player="player-1"/>
```

### Game Ended
```xml
<gameEnded winner="player-1"/>
```

### Multiple Message (batch)
```xml
<multiple>
  <update>
    <tile id="tile-5" x="5" y="3" ...>
      <region id="region-1" .../>
    </tile>
  </update>
  <setStance stance="WAR" source="player-1" target="player-2"/>
  <remove divert="tile-3" array_0="unit-7"/>
</multiple>
```

---

## Implementation Notes (for Swift Client)

### XML Parsing Strategy
- Use Foundation's `XMLParser` (SAX) per line
- Each incoming line is a complete XML document → parse into a tree of `[String: String]` attributes + `[[String: Any]]` children
- Or: simple string scanning for message lines (fast path for trivial/attribute-only messages)

### Connection Lifecycle
1. TCP connect → start receive loop
2. Receive `<gameState>` → determine server state
3. If `<vacantPlayers>` → display nation selection UI
4. Send `<login>` wrapped in `<question>` → wait for reply
5. On successful login: enter game loop (Phase 3+)
6. On disconnect/error: attempt reconnect or return to menu

### Threading Model
- `actor Connection` for serialized access to the socket
- `async` receive loop using `NWConnection.receiveMessage`
- `async` `ask()` with `CheckedContinuation`
- The client's live `Game` is shared with SwiftUI. Access it on `@MainActor`;
  reset, login loading, and all incoming model changes also run on that actor.
  `@unchecked Sendable` does not make the model's dictionaries thread-safe.
- Client delegate callbacks run on the main actor after model changes. Reply
  continuations resume only after the reply's model changes have been applied.
- Login completion installs the live model before publishing the UI's
  lobby/in-game phase, including local games and reconnects.

### Error Handling
- Server errors arrive as `<error>` messages inside `<reply>`
- Connection errors: `NWConnection` state updates → reconnect logic
- Protocol errors: unexpected tag, malformed XML → disconnect + report
