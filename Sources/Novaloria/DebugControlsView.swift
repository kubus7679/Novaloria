import SwiftUI
import NovaloriaClient
import FreeColGame

/// Protocol-/Server-Test-Werkzeuge, die vom Java-Client-Debug-Menue inspiriert sind.
struct DebugControlsView: View {
    @Environment(GameState.self) private var state

    @State private var colonyName: String = "New Amsterdam"
    @State private var tradeRouteId: String = ""
    @State private var currentStopIndex: String = "0"
    @State private var monarchActionType: String = "RAISE_TAX_ACT"
    @State private var aiEnabled: Bool = false
    @State private var stanceValue: String = "WAR"
    @State private var stanceTargetPlayerId: String = "player-2"
    @State private var independenceCountryName: String = "Freedonia"
    @State private var independenceNationName: String = "Free Colonials"
    @State private var chatMessageText: String = ""
    @State private var chatPrivateRecipientId: String = ""
    @State private var claimLandPrice: String = "100"
    @State private var nativeSettlementId: String = ""
    @State private var nativeEnemyPlayerId: String = "player-2"
    @State private var nativeInciteGold: String = "100"
    @State private var nativeChiefResult: String = "model.scout.attackResult.experience"
    @State private var missionaryDirection: String = "N"
    @State private var missionaryDenounce: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let game = state.game {
                    GroupBox("Spieler") {
                        let sorted = game.players.values
                            .filter { $0.playerType == .european }
                        ForEach(Array(sorted), id: \.id) { player in
                            HStack {
                                Circle().fill(colorFor(player: player))
                                    .frame(width: 8, height: 8)
                                Text(player.name ?? player.nationId ?? "?")
                                    .lineLimit(1)
                                Spacer()
                                Text("\(player.gold) G")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }

                    GroupBox("Einheiten") {
                        ForEach(
                            game.units.values.filter { unit in
                                guard let localPlayerId = state.localPlayerId else { return false }
                                return unit.owner == localPlayerId
                            },
                            id: \.id
                        ) { unit in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(unit.unitType.map(state.unitDisplayName) ?? "Einheit")
                                        .font(.caption)
                                    Text(unitLocationLabel(unit, in: game))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    let economyLabel = unitEconomyLabel(unit, in: game)
                                    if !economyLabel.isEmpty {
                                        Text(economyLabel)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(unit.movesLeft) BP")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(GameLabels.state(unit.state))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    GroupBox("Kolonien") {
                        let colonyList = Array(game.colonies.values)
                        ForEach(colonyList, id: \.id) { colony in
                            HStack {
                                Text(colony.name ?? "?")
                                    .font(.caption)
                                Spacer()
                                Text("\(colony.sonsOfLiberty)% Freiheit")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    GroupBox("Handelsroute") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Handelsrouten-ID", text: $tradeRouteId)
                                .textFieldStyle(.roundedBorder)

                            Button("Handelsroute zuweisen (ausgewählte Einheit)") {
                                state.assignSelectedUnitTradeRoute(tradeRouteId)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canAssignSelectedUnitTradeRoute(tradeRouteId))

                            Button("Handelsroute entfernen") {
                                state.clearSelectedUnitTradeRoute()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canClearSelectedUnitTradeRoute)

                            TextField("Index des aktuellen Halts", text: $currentStopIndex)
                                .textFieldStyle(.roundedBorder)

                            Button("Aktuellen Halt festlegen") {
                                state.setSelectedUnitCurrentStop(currentStopIndex)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }

                    if let selected = state.selectedUnit, selected.treasureAmount > 0 {
                        GroupBox("Schatz") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Menge: \(selected.treasureAmount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button("Schatztransport einlösen") {
                                    state.cashInSelectedTreasureTrain()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canCashInSelectedTreasureTrain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    if state.selectedUnit != nil {
                        Button("Hügel ablehnen") {
                            state.declineMoundsForSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Ureinwohner") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Siedlungs-ID", text: $nativeSettlementId)
                                .textFieldStyle(.roundedBorder)

                            TextField("Ergebnis des Häuptlings", text: $nativeChiefResult)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Ausspionieren") {
                                    state.spyOnNativeSettlement(settlementId: nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canSpyOnNativeSettlement || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Geschenk überbringen") {
                                    state.deliverGiftToSettlement(nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canDeliverGiftWithSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button("Geschenk annehmen") {
                                    state.acceptGiftFromNativeSettlement(colonyId: nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canAcceptNativeGift || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Aufstand anzetteln") {
                                    let gold = Int(nativeInciteGold) ?? 0
                                    state.inciteSettlement(settlementId: nativeSettlementId, enemyPlayerId: nativeEnemyPlayerId, gold: gold)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canInciteSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeEnemyPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button("Tribut N") { state.demandTributeFromSettlement(direction: "N") }
                                Button("NO") { state.demandTributeFromSettlement(direction: "NE") }
                                Button("O") { state.demandTributeFromSettlement(direction: "E") }
                                Button("SO") { state.demandTributeFromSettlement(direction: "SE") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canDemandTributeWithSelectedUnit)

                            HStack {
                                Button("S") { state.demandTributeFromSettlement(direction: "S") }
                                Button("SW") { state.demandTributeFromSettlement(direction: "SW") }
                                Button("W") { state.demandTributeFromSettlement(direction: "W") }
                                Button("NW") { state.demandTributeFromSettlement(direction: "NW") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canDemandTributeWithSelectedUnit)

                            HStack {
                                Button("Erkunden N") { state.scoutIndianSettlement(direction: "N") }
                                Button("NO") { state.scoutIndianSettlement(direction: "NE") }
                                Button("O") { state.scoutIndianSettlement(direction: "E") }
                                Button("SO") { state.scoutIndianSettlement(direction: "SE") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            HStack {
                                Button("Erkunden S") { state.scoutIndianSettlement(direction: "S") }
                                Button("SW") { state.scoutIndianSettlement(direction: "SW") }
                                Button("W") { state.scoutIndianSettlement(direction: "W") }
                                Button("NW") { state.scoutIndianSettlement(direction: "NW") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            Button("Mit Häuptling sprechen") {
                                state.scoutSpeakToChief(settlementId: nativeSettlementId, result: nativeChiefResult)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutSpeakToChief || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeChiefResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Divider()

                            Text("Missionar")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Richtung", text: $missionaryDirection)
                                .textFieldStyle(.roundedBorder)

                            Toggle("Anprangern", isOn: $missionaryDenounce)

                            Button("Missionarsaktion") {
                                state.sendMissionaryAction(direction: missionaryDirection, denounce: missionaryDenounce)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canSendMissionaryAction || missionaryDirection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            TextField("Spieler-ID des Gegners", text: $nativeEnemyPlayerId)
                                .textFieldStyle(.roundedBorder)
                            TextField("Gold für den Aufstand", text: $nativeInciteGold)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 4)
                    }

                    Button("Weiterspielen") {
                        state.sendContinue()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Aufgeben") {
                        state.retireGame()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Rachemodus starten") {
                        state.enterRevengeMode()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Monarch-Aktionstyp", text: $monarchActionType)
                        .textFieldStyle(.roundedBorder)

                    Button("Monarch-Aktion") {
                        state.sendMonarchAction(monarchActionType)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(monarchActionType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Toggle("KI aktiv", isOn: $aiEnabled)

                    Button("KI-Einstellung übernehmen") {
                        state.setLocalPlayerAI(aiEnabled)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Als verfügbar markieren") {
                        state.setLocalPlayerAvailable()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Haltung", text: $stanceValue)
                        .textFieldStyle(.roundedBorder)

                    TextField("Zielspieler-ID der Haltung", text: $stanceTargetPlayerId)
                        .textFieldStyle(.roundedBorder)

                    Button("Haltung festlegen") {
                        state.setStance(stance: stanceValue, targetPlayerId: stanceTargetPlayerId)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        stanceValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || stanceTargetPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    TextField("Name des unabhängigen Landes", text: $independenceCountryName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Name der unabhängigen Nation", text: $independenceNationName)
                        .textFieldStyle(.roundedBorder)

                    Button("Unabhängigkeit erklären") {
                        state.declareIndependence(
                            countryName: independenceCountryName,
                            nationName: independenceNationName
                        )
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        independenceCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || independenceNationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    TextField("Chatnachricht", text: $chatMessageText)
                        .textFieldStyle(.roundedBorder)

                    TextField("Optionale Empfänger-Spieler-ID", text: $chatPrivateRecipientId)
                        .textFieldStyle(.roundedBorder)

                    if !state.incomingChatLog.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(state.incomingChatLog, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Button("Chatnachricht senden") {
                        state.sendChatMessage(
                            message: chatMessageText,
                            privateRecipientId: chatPrivateRecipientId
                        )
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Als ausgeschieden markieren") {
                        state.setLocalPlayerDead()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Preis für Land beanspruchen", text: $claimLandPrice)
                        .textFieldStyle(.roundedBorder)

                    Button("Ausgewähltes Feld beanspruchen") {
                        if let tileId = state.selectedTileId {
                            state.claimLand(price: claimLandPrice, tileId: tileId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(state.selectedTileId == nil || claimLandPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
    }

    private func unitLocationLabel(_ unit: FreeColGame.Unit, in game: Game) -> String {
        guard let location = unit.location else { return "?" }
        if let carrier = game.units[location] {
            return "An Bord von \(carrier.unitType.map(state.unitDisplayName) ?? "Transporter")"
        }
        if game.tiles[location] != nil {
            return location
        }
        if game.colonies[location] != nil {
            return "In der Kolonie"
        }
        return location
    }

    private func unitEconomyLabel(_ unit: FreeColGame.Unit, in game: Game) -> String {
        var parts: [String] = []
        if let tradeRoute = unit.tradeRoute, !tradeRoute.isEmpty {
            parts.append("Route: \(tradeRoute)")
        }
        if unit.currentStop > 0 || unit.tradeRoute != nil {
            parts.append("Halt: \(unit.currentStop)")
        }
        if unit.treasureAmount > 0 {
            parts.append("Schatz: \(unit.treasureAmount)")
        }
        if let carrierId = unit.location, game.units[carrierId] != nil {
            let cargoCount = game.units.values.filter { $0.location == carrierId }.count
            parts.append("Fracht: \(cargoCount)")
        }
        return parts.joined(separator: " | ")
    }

    private func colorFor(player: Player) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(player.id.hashValue) % colors.count
        return colors[idx]
    }
}
