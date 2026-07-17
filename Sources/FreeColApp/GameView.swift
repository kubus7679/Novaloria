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
    @State private var europeRecruitUnitType: String = "model.unit.freeColonist"
    @State private var nativeSettlementId: String = ""
    @State private var nativeEnemyPlayerId: String = "player-2"
    @State private var nativeInciteGold: String = "100"
    @State private var nativeChiefResult: String = "model.scout.attackResult.experience"
    @State private var missionaryDirection: String = "N"
    @State private var missionaryDenounce: Bool = false

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

                    if let localPlayer = state.localPlayer {
                        GroupBox("Europe") {
                            VStack(alignment: .leading, spacing: 6) {
                                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                                    GridRow {
                                        Text("Gold")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(localPlayer.gold)")
                                            .font(.caption2)
                                    }
                                    GridRow {
                                        Text("Tax")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(localPlayer.tax)%")
                                            .font(.caption2)
                                    }
                                    GridRow {
                                        Text("Immigration")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(localPlayer.immigration)")
                                            .font(.caption2)
                                    }
                                    GridRow {
                                        Text("Liberty")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(localPlayer.liberty)")
                                            .font(.caption2)
                                    }
                                    GridRow {
                                        Text("Score")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(localPlayer.score)")
                                            .font(.caption2)
                                    }
                                }

                                Divider()

                                Text("Units in Europe / High Seas")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                if state.europeUnits.isEmpty {
                                    Text("No units waiting in Europe.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(state.europeUnits, id: \.id) { unit in
                                        HStack {
                                            Text(unit.unitType ?? unit.id)
                                                .font(.caption2)
                                            Spacer()
                                            Text(unit.state.rawValue)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Divider()

                                TextField("Unit type to train", text: $europeRecruitUnitType)
                                    .textFieldStyle(.roundedBorder)

                                Button("Train Unit in Europe") {
                                    state.trainUnitInEurope(unitType: europeRecruitUnitType)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                                .disabled(europeRecruitUnitType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.vertical, 4)
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
                                if let carrier = state.selectedUnitCarrier {
                                    HStack {
                                        Text("Aboard: \(carrier.unitType ?? carrier.id)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("Select Carrier") {
                                            state.selectUnit(carrier.id, onTile: state.selectedTileId)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                Button("Set Active") {
                                    state.setSelectedUnitState(.active)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canChangeSelectedUnitState(to: .active))

                                Button("Equip Missionary") {
                                    state.equipSelectedUnitForRole("model.role.missionary", count: 1)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canEquipSelectedUnitForRole)

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

                        if state.selectedUnitIsCarrier {
                            GroupBox("Cargo") {
                                VStack(alignment: .leading, spacing: 6) {
                                    if state.selectedUnitCargoUnits.isEmpty {
                                        Text("No units aboard.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else {
                                        ForEach(state.selectedUnitCargoUnits, id: \.id) { unit in
                                            HStack {
                                                Button(unit.unitType ?? unit.id) {
                                                    state.selectUnit(unit.id, onTile: state.selectedTileId)
                                                }
                                                .buttonStyle(.bordered)
                                                Spacer()
                                                Text("\(unit.movesLeft) MP")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(unit.state.rawValue)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if state.canDisembarkSelectedUnit {
                                            Button("Disembark Selected Cargo") {
                                                state.disembarkSelectedUnit()
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(maxWidth: .infinity)
                                        } else {
                                            Text("Select a cargo unit to disembark it.")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
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
