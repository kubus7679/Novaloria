import SwiftUI
import FreeColClient
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
                    GroupBox("Players") {
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

                    GroupBox("Units") {
                        ForEach(
                            game.units.values.filter { unit in
                                guard let localPlayerId = state.localPlayerId else { return false }
                                return unit.owner == localPlayerId
                            },
                            id: \.id
                        ) { unit in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(unit.unitType ?? "Unit")
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
                                    Text("\(unit.movesLeft) MP")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(unit.state.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    GroupBox("Colonies") {
                        let colonyList = Array(game.colonies.values)
                        ForEach(colonyList, id: \.id) { colony in
                            HStack {
                                Text(colony.name ?? "?")
                                    .font(.caption)
                                Spacer()
                                Text("\(colony.sonsOfLiberty)% SoL")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    GroupBox("Trade Route") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Trade Route ID", text: $tradeRouteId)
                                .textFieldStyle(.roundedBorder)

                            Button("Assign Trade Route (Selected Unit)") {
                                state.assignSelectedUnitTradeRoute(tradeRouteId)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canAssignSelectedUnitTradeRoute(tradeRouteId))

                            Button("Clear Trade Route") {
                                state.clearSelectedUnitTradeRoute()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canClearSelectedUnitTradeRoute)

                            TextField("Current Stop Index", text: $currentStopIndex)
                                .textFieldStyle(.roundedBorder)

                            Button("Set Current Stop") {
                                state.setSelectedUnitCurrentStop(currentStopIndex)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }

                    if let selected = state.selectedUnit, selected.treasureAmount > 0 {
                        GroupBox("Treasure") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Amount: \(selected.treasureAmount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button("Cash In Treasure Train") {
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
                        Button("Decline Mounds") {
                            state.declineMoundsForSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Native") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Settlement ID", text: $nativeSettlementId)
                                .textFieldStyle(.roundedBorder)

                            TextField("Chief result", text: $nativeChiefResult)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Spy") {
                                    state.spyOnNativeSettlement(settlementId: nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canSpyOnNativeSettlement || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Gift") {
                                    state.deliverGiftToSettlement(nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canDeliverGiftWithSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button("Accept Gift") {
                                    state.acceptGiftFromNativeSettlement(colonyId: nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canAcceptNativeGift || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Incite") {
                                    let gold = Int(nativeInciteGold) ?? 0
                                    state.inciteSettlement(settlementId: nativeSettlementId, enemyPlayerId: nativeEnemyPlayerId, gold: gold)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canInciteSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeEnemyPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button("Demand N") { state.demandTributeFromSettlement(direction: "N") }
                                Button("NE") { state.demandTributeFromSettlement(direction: "NE") }
                                Button("E") { state.demandTributeFromSettlement(direction: "E") }
                                Button("SE") { state.demandTributeFromSettlement(direction: "SE") }
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
                                Button("Scout N") { state.scoutIndianSettlement(direction: "N") }
                                Button("NE") { state.scoutIndianSettlement(direction: "NE") }
                                Button("E") { state.scoutIndianSettlement(direction: "E") }
                                Button("SE") { state.scoutIndianSettlement(direction: "SE") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            HStack {
                                Button("Scout S") { state.scoutIndianSettlement(direction: "S") }
                                Button("SW") { state.scoutIndianSettlement(direction: "SW") }
                                Button("W") { state.scoutIndianSettlement(direction: "W") }
                                Button("NW") { state.scoutIndianSettlement(direction: "NW") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            Button("Speak to Chief") {
                                state.scoutSpeakToChief(settlementId: nativeSettlementId, result: nativeChiefResult)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutSpeakToChief || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeChiefResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Divider()

                            Text("Missionary")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Direction", text: $missionaryDirection)
                                .textFieldStyle(.roundedBorder)

                            Toggle("Denounce", isOn: $missionaryDenounce)

                            Button("Missionary Action") {
                                state.sendMissionaryAction(direction: missionaryDirection, denounce: missionaryDenounce)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canSendMissionaryAction || missionaryDirection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            TextField("Enemy player ID", text: $nativeEnemyPlayerId)
                                .textFieldStyle(.roundedBorder)
                            TextField("Incite gold", text: $nativeInciteGold)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 4)
                    }

                    Button("Continue") {
                        state.sendContinue()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Retire") {
                        state.retireGame()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Enter Revenge Mode") {
                        state.enterRevengeMode()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Monarch action type", text: $monarchActionType)
                        .textFieldStyle(.roundedBorder)

                    Button("Monarch Action") {
                        state.sendMonarchAction(monarchActionType)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(monarchActionType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Toggle("AI Enabled", isOn: $aiEnabled)

                    Button("Apply AI Setting") {
                        state.setLocalPlayerAI(aiEnabled)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Set Available") {
                        state.setLocalPlayerAvailable()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Stance", text: $stanceValue)
                        .textFieldStyle(.roundedBorder)

                    TextField("Stance target player", text: $stanceTargetPlayerId)
                        .textFieldStyle(.roundedBorder)

                    Button("Set Stance") {
                        state.setStance(stance: stanceValue, targetPlayerId: stanceTargetPlayerId)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        stanceValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || stanceTargetPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    TextField("Independence country name", text: $independenceCountryName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Independence nation name", text: $independenceNationName)
                        .textFieldStyle(.roundedBorder)

                    Button("Declare Independence") {
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

                    TextField("Chat message", text: $chatMessageText)
                        .textFieldStyle(.roundedBorder)

                    TextField("Private recipient player id (optional)", text: $chatPrivateRecipientId)
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

                    Button("Send Chat") {
                        state.sendChatMessage(
                            message: chatMessageText,
                            privateRecipientId: chatPrivateRecipientId
                        )
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Set Dead") {
                        state.setLocalPlayerDead()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("Claim land price", text: $claimLandPrice)
                        .textFieldStyle(.roundedBorder)

                    Button("Claim Selected Tile") {
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
            return "Aboard \(carrier.unitType ?? carrier.id)"
        }
        if game.tiles[location] != nil {
            return location
        }
        if game.colonies[location] != nil {
            return "In colony"
        }
        return location
    }

    private func unitEconomyLabel(_ unit: FreeColGame.Unit, in game: Game) -> String {
        var parts: [String] = []
        if let tradeRoute = unit.tradeRoute, !tradeRoute.isEmpty {
            parts.append("Route: \(tradeRoute)")
        }
        if unit.currentStop > 0 || unit.tradeRoute != nil {
            parts.append("Stop: \(unit.currentStop)")
        }
        if unit.treasureAmount > 0 {
            parts.append("Treasure: \(unit.treasureAmount)")
        }
        if let carrierId = unit.location, game.units[carrierId] != nil {
            let cargoCount = game.units.values.filter { $0.location == carrierId }.count
            parts.append("Cargo: \(cargoCount)")
        }
        return parts.joined(separator: " | ")
    }

    private func colorFor(player: Player) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(player.id.hashValue) % colors.count
        return colors[idx]
    }
}