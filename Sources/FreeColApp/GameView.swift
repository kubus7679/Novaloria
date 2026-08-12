import SwiftUI
import FreeColClient
import FreeColGame

struct GameView: View {
    @Environment(GameState.self) private var state

    @State private var colonyName: String = "New Amsterdam"
    @State private var lastColonyTileId: String?
    @State private var mapViewport: MapViewportInfo?

    var body: some View {
        ZStack {
            Color(white: 0.08)
                .ignoresSafeArea()
            MapView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 0) {
                topBar
                Spacer()
            }
        }
        .overlay(alignment: .bottom) {
            OrderButtonBar()
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomLeading) {
            MiniMapView(viewport: mapViewport)
                .frame(width: 160)
                .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            InfoPanelView()
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            if state.selectedUnit != nil {
                unitQuickActions
                    .padding(.trailing, 8)
                    .padding(.top, 4)
            }
        }
        .sheet(isPresented: Binding(
            get: { state.showEuropePanel },
            set: { state.showEuropePanel = $0 }
        )) {
            EuropePanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showColonyPanel && state.selectedColony != nil },
            set: { if !$0 { state.closeColonyPanel() } }
        )) {
            if let selectedColony = state.selectedColony, let game = state.game {
                VStack(spacing: 0) {
                    HStack {
                        Text(selectedColony.name ?? "Colony")
                            .font(.title.bold())
                        Spacer()
                        Button("Close") { state.closeColonyPanel() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    Divider()
                    ScrollView {
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
            }
        }
        }
        .sheet(isPresented: Binding(
            get: { state.showDebugPanel },
            set: { state.showDebugPanel = $0 }
        )) {
            DebugControlsView()
                .frame(minWidth: 380, minHeight: 500)
        }
        .onChange(of: state.selectedColony?.tileId) { _, newValue in
            // Clicking a colony tile on the map opens the colony panel (Java behaviour).
            if let newValue, newValue != lastColonyTileId {
                lastColonyTileId = newValue
                if state.selectedUnit == nil {
                    state.openColonyPanel()
                }
            } else if newValue == nil {
                lastColonyTileId = nil
            }
        }
        .onPreferenceChange(MapViewportKey.self) { info in
            mapViewport = info
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Disconnect") { state.disconnect() }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let game = state.game {
                let turnInfo = yearSeason(for: game.turn.number)
                Text("Turn \(game.turn.number)")
                    .font(.headline)
                if let season = turnInfo.season {
                    Text("\(season) \(turnInfo.year)")
                        .font(.caption)
                } else {
                    Text("Year \(turnInfo.year)")
                        .font(.caption)
                }
                if let cp = game.currentPlayerId, let player = game.players[cp] {
                    Text(player.name ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                if let local = state.localPlayer {
                    Text("Gold: \(local.gold)")
                    Text("Tax: \(local.tax)%")
                    Text("Score: \(local.score)")
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.92))
    }

    /// Compact floating action card for the selected unit (Java quick-actions equivalent).
    private var unitQuickActions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let selected = state.selectedUnit {
                    Text(selected.unitType ?? "Unit")
                        .font(.caption.bold())
                    Text("\(selected.state.rawValue) | \(selected.movesLeft) MP")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Set Active") {
                        state.setSelectedUnitState(.active)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .active))

                    if state.canBuildSelectedColony {
                        TextField("Colony name", text: $colonyName)
                            .textFieldStyle(.roundedBorder)
                        Button("Build Colony") {
                            state.buildColony(name: colonyName)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(colonyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if state.canJoinSelectedColony {
                        Button("Join Colony") {
                            state.joinSelectedColony()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.embarkCarrierOptions.isEmpty {
                        ForEach(state.embarkCarrierOptions, id: \.id) { carrier in
                            Button("Embark on \(carrier.unitType ?? carrier.id)") {
                                state.embarkSelectedUnit(onCarrier: carrier.id)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if state.canDisembarkSelectedUnit {
                        Button("Disembark") {
                            state.disembarkSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if state.canDisbandSelectedUnit {
                        Button("Disband Unit") {
                            state.disbandSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let targetTileId = state.selectedTileId,
                       state.canAttackSelectedUnitMelee(onTile: targetTileId) || state.canAttackSelectedUnitRanged(onTile: targetTileId) {
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

                    Button("Equip Missionary") {
                        state.equipSelectedUnitForRole("model.role.missionary", count: 1)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canEquipSelectedUnitForRole)
                }
            }
            .padding(8)
            .frame(maxWidth: 220)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
        }
        .frame(maxHeight: 340)
        .scrollIndicators(.hidden)
    }

    private func yearSeason(for turn: Int) -> (year: Int, season: String?) {
        // Java-like calculation (Turn.java): starting year 1492, seasons split in 1600.
        let raw = turn - 1 + 1492
        if raw < 1600 {
            return (raw, nil)
        }
        let delta = raw - 1600
        return (1600 + delta / 2, delta % 2 == 0 ? "Spring" : "Autumn")
    }
}