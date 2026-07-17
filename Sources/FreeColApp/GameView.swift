import SwiftUI
import FreeColClient
import FreeColGame

struct GameView: View {
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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HSplitView {
                MapView()
                    .frame(minWidth: 400)
                infoPanel
                    .frame(width: 250)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Disconnect") { state.disconnect() }
            }
        }
    }

    private var topBar: some View {
        HStack {
            if let game = state.game {
                Text("Turn \(game.turn.number)")
                    .font(.headline)
                if let cp = game.currentPlayerId, let player = game.players[cp] {
                    Text(player.name ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                Text(state.isLocalPlayersTurn ? "Your turn" : "Waiting")
                    .font(.caption)
                    .foregroundColor(state.isLocalPlayersTurn ? .green : .secondary)
            }
            Spacer()
            if !state.statusMessage.isEmpty {
                Text(state.statusMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            if let err = state.errorMessage, !err.isEmpty {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var infoPanel: some View {
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
                                Text(unit.unitType ?? "Unit")
                                    .font(.caption)
                                Spacer()
                                Text("\(unit.movesLeft) MP")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(unit.state.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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

                    if let selectedColony = state.selectedColony {
                        ColonyPanelView(
                            colony: selectedColony,
                            ownerName: game.players[selectedColony.owner ?? ""]?.name ?? "Unknown",
                            units: state.selectedColonyUnits,
                            canManage: state.canManageSelectedColony,
                            selectedWorkerUnitId: state.selectedColonyWorkerUnitId,
                            onChangeWorkType: { workTypeId in
                                state.changeSelectedColonyWorkerWorkType(workTypeId)
                            },
                            onChangeWorkImprovementType: { improvementTypeId in
                                state.changeSelectedColonyWorkerWorkImprovementType(improvementTypeId)
                            },
                            onClearSpeciality: {
                                state.clearSelectedColonyWorkerSpeciality()
                            },
                            onAssignTeacher: { teacherId in
                                state.assignTeacherToSelectedColonyWorker(teacherId)
                            },
                            onClearTeacher: {
                                state.clearTeacherForSelectedColonyWorker()
                            },
                            onWorkAtLocation: { workLocationId in
                                state.setSelectedColonyWorkerWorkLocation(workLocationId)
                            },
                            onRenameColony: { newName in
                                state.renameSelectedColony(to: newName)
                            },
                            onPayForBuilding: {
                                state.payForSelectedColonyBuilding()
                            },
                            onSetGoodsLevels: {
                                state.setSelectedColonyGoodsLevels()
                            },
                            onAbandonColony: {
                                state.abandonSelectedColony()
                            },
                            canAbandonColony: state.canAbandonSelectedColony,
                            onRearrangeColony: {
                                state.rearrangeSelectedColony()
                            },
                            onSetBuildQueue: { queueIds in
                                state.setSelectedColonyBuildQueue(queueIds)
                            },
                            onPutOutsideColony: {
                                state.putSelectedColonyWorkerOutside()
                            },
                            canPutOutsideColony: state.canPutSelectedColonyWorkerOutside,
                            selectedCarrierId: state.selectedColonyCarrierId,
                            onLoadGoods: { typeId, amount in
                                state.loadGoodsForSelectedColony(typeId: typeId, amount: amount)
                            },
                            onUnloadGoods: { typeId, amount in
                                state.unloadGoodsFromSelectedCarrier(typeId: typeId, amount: amount)
                            }
                        )
                    }

                    if state.canBuildSelectedColony {
                        GroupBox("Build Colony") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Colony name", text: $colonyName)
                                    .textFieldStyle(.roundedBorder)
                                Button("Build") {
                                    state.buildColony(name: colonyName)
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                                .disabled(colonyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if state.canJoinSelectedColony {
                        Button("Join Colony") {
                            state.joinSelectedColony()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    if !state.embarkCarrierOptions.isEmpty {
                        GroupBox("Embark") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(state.embarkCarrierOptions, id: \.id) { carrier in
                                    Button("Embark on \(carrier.unitType ?? carrier.id)") {
                                        state.embarkSelectedUnit(onCarrier: carrier.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if state.canDisembarkSelectedUnit {
                        Button("Disembark") {
                            state.disembarkSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    if state.canDisbandSelectedUnit {
                        Button("Disband Unit") {
                            state.disbandSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    if let targetTileId = state.selectedTileId,
                       state.canAttackSelectedUnitMelee(onTile: targetTileId) || state.canAttackSelectedUnitRanged(onTile: targetTileId) {
                        GroupBox("Combat") {
                            VStack(alignment: .leading, spacing: 6) {
                                Button("Attack (Melee)") {
                                    state.attackSelectedUnitMelee(onTile: targetTileId)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canAttackSelectedUnitMelee(onTile: targetTileId))

                                Button("Attack (Ranged)") {
                                    state.attackSelectedUnitRanged(onTile: targetTileId)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canAttackSelectedUnitRanged(onTile: targetTileId))
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let selected = state.selectedUnit {
                        GroupBox("Unit State") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selected.state.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Moves Left: \(selected.movesLeft)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button("Set Active") {
                                    state.setSelectedUnitState(.active)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canChangeSelectedUnitState(to: .active))

                                Button("Fortify") {
                                    state.setSelectedUnitState(.fortifying)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canChangeSelectedUnitState(to: .fortifying))

                                Button("Sentry") {
                                    state.setSelectedUnitState(.sentry)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canChangeSelectedUnitState(to: .sentry))

                                Button("Skip") {
                                    state.setSelectedUnitState(.skipped)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                            }
                            .padding(.vertical, 4)
                        }

                        GroupBox("Destination") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selected.destination ?? "none")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button("Set Destination (Selected Tile)") {
                                    if let tileId = state.selectedTileId {
                                        state.setSelectedUnitDestination(to: tileId)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canSetDestinationToSelectedTile)

                                Button("Clear Destination") {
                                    state.clearSelectedUnitDestination()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canClearSelectedUnitDestination)
                            }
                            .padding(.vertical, 4)
                        }

                        GroupBox("Trade Route") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selected.tradeRoute ?? "none")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                TextField("Trade Route ID", text: $tradeRouteId)
                                    .textFieldStyle(.roundedBorder)

                                Button("Assign Trade Route") {
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

                        if selected.treasureAmount > 0 {
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

                        Button("Decline Mounds") {
                            state.declineMoundsForSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("End Turn") {
                        state.endTurn()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!state.canEndTurn)

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

    private func colorFor(player: Player) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(player.id.hashValue) % colors.count
        return colors[idx]
    }
}
