import SwiftUI
import NovaloriaClient
import FreeColGame

struct GameView: View {
    @Environment(GameState.self) private var state

    @State private var colonyName: String = "New Amsterdam"
    @State private var mapViewport: MapViewportInfo?
    @State private var selectedLootTypes: Set<String> = []
    @State private var namePromptText: String = ""
    @State private var showNativeTrade = false
    @State private var showDiplomacy = false
    @State private var independenceCountry = "United States"
    @State private var independenceNation = "America"
    @State private var findSettlementQuery = ""
    @State private var queuedActionToConfirm: GameState.QueuedGameplayAction?
    @State private var showQueuedActionConfirmation = false

    var body: some View {
        KeyboardShortcutHandlerView {
            VStack(spacing: 0) {
            topBar

            if !state.queuedGameplayActions.isEmpty {
                ScrollView { queuedActionsPanel }
                    .frame(maxHeight: 130)
            }
            if state.isChoosingMoveDestination {
                HStack {
                    Text(L10n.text("Bewegen: Zielfeld auf der Karte anklicken.", table: "GameView"))
                    Spacer()
                    Button(L10n.text("Abbrechen", table: "GameView")) { state.cancelChoosingMoveDestination() }
                        .keyboardShortcut(.cancelAction)
                }
                .font(.callout)
                .padding(8)
                .background(Color.accentColor.opacity(0.2))
            }

            HStack(spacing: 0) {
                MapView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(state.pendingServerDecision == nil && !state.isDefeated && !state.isVictorious)
                    .overlay(alignment: .topLeading) {
                        if let message = state.errorMessage, !message.isEmpty {
                            errorBanner(message)
                                .padding(10)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let tileId = state.tileActionTileId {
                            GeometryReader { geo in
                                ScrollView {
                                    TilePopupView(tileId: tileId)
                                }
                                .frame(width: 240, height: max(0, min(520, geo.size.height - 16)))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .overlay {
                        EventMessagesOverlay()
                            .allowsHitTesting(state.pendingServerDecision == nil)
                    }
                    .overlay {
                        if let pending = state.pendingServerDecision {
                            mapDecisionOverlay(for: pending)
                        }
                    }
                    .overlay {
                        if state.isDefeated {
                            defeatOverlay
                        } else if state.isVictorious {
                            victoryOverlay
                        }
                    }
                Divider()
                GeometryReader { inspectorGeometry in
                    VStack(spacing: 0) {
                        MiniMapView(viewport: mapViewport, minimapWidth: 244, maxMiniHeight: 112)
                            .frame(height: 112)
                            .padding(8)
                        Divider()
                        Group {
                            if state.selectedUnit != nil {
                                unitQuickActions
                            } else {
                                ScrollView { InfoPanelView() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(width: 260, height: inspectorGeometry.size.height)
                }
                .frame(width: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack(spacing: 12) {
                Text(state.turnStatusDescription)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if state.unitsAwaitingOrders.isEmpty {
                    Label(L10n.text("Alle Einheiten befohlen", table: "GameView"), systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        state.selectAdjacentUnit(forward: true, onlyAwaitingOrders: true)
                    } label: {
                        Label(L10n.text("\(state.unitsAwaitingOrders.count) ohne Befehl", table: "GameView"),
                              systemImage: "arrow.right.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text("Wählt die nächste Einheit ohne Befehl aus und zentriert die Karte, falls sie sich dort befindet.", table: "GameView"))
                    .accessibilityLabel(L10n.text("\(state.unitsAwaitingOrders.count) Einheiten ohne Befehl. Nächste Einheit auswählen.", table: "GameView"))
                    .accessibilityIdentifier("units-awaiting-orders")
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .background(Color(white: 0.08))
        .sheet(
            isPresented: Binding(
                get: { state.showEuropePanel },
                set: { state.showEuropePanel = $0 }
            )
        ) {
            EuropePanelView()
                .frame(idealWidth: 760)
        }

        .sheet(
            isPresented: Binding(
                get: { state.showColonyPanel && state.selectedColony != nil },
                set: { if !$0 { state.closeColonyPanel() } }
            )
        ) {
            if let selectedColony = state.selectedColony, let game = state.game {
                VStack(spacing: 0) {
                    HStack {
                        Menu {
                            ForEach(state.coloniesForNavigation) { colony in
                                Button {
                                    state.openColonyPanel(colonyId: colony.id)
                                } label: {
                                    if colony.id == selectedColony.id {
                                        Label(colony.name ?? L10n.text("Kolonie", table: "GameView"), systemImage: "checkmark")
                                    } else {
                                        Text(colony.name ?? L10n.text("Kolonie", table: "GameView"))
                                    }
                                }
                                .accessibilityIdentifier("select-colony-\(colony.id)")
                            }
                        } label: {
                            Text(selectedColony.name ?? L10n.text("Kolonie", table: "GameView"))
                                .font(.title2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.tail)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .disabled(state.coloniesForNavigation.isEmpty)
                        .accessibilityLabel(L10n.text("Kolonie auswählen", table: "GameView"))
                        .accessibilityIdentifier("colony-selector")
                        Spacer()
                        Button {
                            state.selectPreviousColony()
                        } label: {
                            Label(L10n.text("Vorherige", table: "GameView"), systemImage: "chevron.left")
                        }
                        .disabled(!state.canNavigateColonies)
                        .accessibilityIdentifier("previous-colony")
                        Button {
                            state.selectNextColony()
                        } label: {
                            Label(L10n.text("Nächste", table: "GameView"), systemImage: "chevron.right")
                        }
                        .disabled(!state.canNavigateColonies)
                        .accessibilityIdentifier("next-colony")
                        Button(L10n.text("Schließen", table: "GameView")) { state.closeColonyPanel() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding()
                    if let error = state.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                            .accessibilityIdentifier("colony-error")
                    }
                    Divider()
                    ColonyPanelView(
                        colony: selectedColony,
                        ownerName: game.players[selectedColony.owner ?? ""]?.name ?? "Unknown",
                        units: state.selectedColonyUnits.filter { state.canUnitWorkInColony($0) },
                        canManage: state.canManageSelectedColony,
                        selectedWorkerUnitId: state.selectedColonyWorkerUnitId,
                        population: state.colonyPopulation(selectedColony),
                        terrainFields: state.selectedColonyTerrain,
                        onSelectWorker: { unitId in
                            state.selectUnit(unitId, onTile: selectedColony.tileId)
                        },
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
                        onWorkAtLocation: { workLocationId, workTypeId in
                            state.assignSelectedColonyWorker(to: workLocationId, workTypeId: workTypeId)
                        },
                        onRenameColony: { newName in
                            state.renameSelectedColony(to: newName)
                        },
                        onPayForBuilding: {
                            state.payForSelectedColonyBuilding()
                        },
                        onSetGoodsLevel: { data in
                            state.setSelectedColonyGoodsLevel(data)
                        },
                        exportData: state.selectedColonyExportData,
                        workLocationCandidates: state.selectedColonyWorkLocationCandidates,
                        buildingWorkplaces: state.selectedColonyBuildingWorkplaces,
                        teacherCandidates: state.selectedColonyTeacherCandidates,
                        workTypeCandidates: state.selectedColonyWorkTypeCandidates,
                        goodsCandidates: state.colonyGoodsCandidates,
                        workImprovementCandidates: state.selectedColonyWorkImprovementCandidates,
                        onAbandonColony: {
                            state.abandonSelectedColony()
                        },
                        canAbandonColony: state.canAbandonSelectedColony,
                        onSetBuildQueue: { queueIds in
                            state.setSelectedColonyBuildQueue(queueIds)
                        },
                        onPutOutsideColony: {
                            state.putSelectedColonyWorkerOutside()
                        },
                        canPutOutsideColony: state.canPutSelectedColonyWorkerOutside,
                        selectedCarrierId: state.selectedColonyCarrierId,
                        selectedCarrierDescription: state.selectedColonyCarrierDescription,
                        carrierCandidates: state.selectedColonyCarrierCandidates,
                        onSelectCarrier: { carrierId in
                            state.selectUnit(carrierId, onTile: selectedColony.tileId)
                        },
                        onLoadGoods: { typeId, amount in
                            state.loadGoodsForSelectedColony(typeId: typeId, amount: amount)
                        },
                        onUnloadGoods: { typeId, amount in
                            state.unloadGoodsFromSelectedCarrier(typeId: typeId, amount: amount)
                        },
                        maximumLoadAmount: { typeId in
                            state.maximumGoodsLoadAmountForSelectedColony(typeId: typeId)
                        },
                        maximumUnloadAmount: { typeId in
                            state.maximumGoodsUnloadAmountFromSelectedCarrier(typeId: typeId)
                        },
                        buildableCandidates: state.selectedColonyBuildableCandidates,
                        buildings: state.selectedColonyBuildings,
                        currentBuildQueue: state.selectedColonyBuildQueue,
                        buildingLabel: { state.buildingDisplayName($0) },
                        storedGoods: state.selectedColonyStoredGoods,
                        warehouseCapacity: state.selectedColonyWarehouseCapacity,
                        carrierGoods: state.selectedColonyCarrierGoods,
                        buildTargetLabel: state.selectedColonyBuildTarget?.label,
                        buildRequirements: state.selectedColonyBuildRequirements,
                        buildPaymentCost: state.selectedColonyBuildPaymentCost,
                        buildETATurns: state.selectedColonyEstimatedBuildTurns,
                        estimatedBuildPerTurn: state.selectedColonyEstimatedBuildPerTurn,
                        estimatedProduction: state.selectedColonyEstimatedProduction,
                        efficiencyProgress: state.colonyEfficiencyProgress(selectedColony),
                        growthETATurns: state.selectedColonyEstimatedGrowthTurns,
                        foodGoodsIds: state.selectedColonyFoodGoodsIds,
                        availableGold: state.localPlayer?.gold ?? 0,
                        onClaimLand: { tileId, price in
                            state.claimLand(price: price, tileId: tileId, claimantId: selectedColony.id)
                        }
                    )
                    .id(selectedColony.id)
                }
                .frame(
                    minWidth: 1000, idealWidth: 1280, maxWidth: 1600,
                    minHeight: 640, idealHeight: 800, maxHeight: 1000)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { state.showNativeSettlementPanel && state.selectedNativeSettlement != nil },
                set: { if !$0 { state.closeNativeSettlementPanel() } }
            )
        ) {
            NativeSettlementPanelView()
        }
        .sheet(
            isPresented: Binding(
                get: { state.showDebugPanel },
                set: { state.showDebugPanel = $0 }
            )
        ) {
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.text("Diagnose", table: "GameView")).font(.headline)
                    Spacer()
                    Button(L10n.text("Schließen", table: "GameView")) { state.closeDebugPanel() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding()
                Divider()
                DebugControlsView()
            }
            .frame(minWidth: 520, idealWidth: 640,
                   minHeight: 400, idealHeight: 640, maxHeight: 760)
        }
        .sheet(isPresented: Binding(
            get: { state.showReportsPanel },
            set: { state.showReportsPanel = $0 }
        )) {
            ReportPanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showChatPanel },
            set: { state.showChatPanel = $0 }
        )) {
            ChatPanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showPreferencesPanel },
            set: { state.showPreferencesPanel = $0 }
        )) {
            PreferencesView()
        }
        .sheet(isPresented: Binding(
            get: { state.showColopediaPanel },
            set: { state.showColopediaPanel = $0 }
        )) {
            ColopediaView(categoryFilter: state.requestedColopediaCategory)
        }
        .sheet(isPresented: Binding(
            get: { state.showStatusPanel },
            set: { state.showStatusPanel = $0 }
        )) {
            StatusPanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showShortcutsHelp },
            set: { state.showShortcutsHelp = $0 }
        )) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: Binding(
            get: { state.showIndependencePanel },
            set: { state.showIndependencePanel = $0 }
        )) {
            independenceSheet
        }
        .sheet(isPresented: Binding(
            get: { state.showFindSettlementPanel },
            set: { state.showFindSettlementPanel = $0 }
        )) {
            findSettlementSheet
        }
        .sheet(isPresented: Binding(
            get: { state.showTradeRoutesPanel },
            set: { state.showTradeRoutesPanel = $0 }
        )) {
            TradeRoutePanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showEndTurnDialog },
            set: { if !$0 { state.dismissEndTurnDialog() } }
        )) {
            endTurnDialog
        }
        .confirmationDialog(
            L10n.text("Angriff bestätigen", table: "GameView"),
            isPresented: Binding(
                get: { state.showAttackConfirmation },
                set: { if !$0 { state.dismissPendingAttack() } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("Angreifen", table: "GameView"), role: .destructive) { state.confirmPendingAttack() }
            Button(L10n.text("Abbrechen", table: "GameView"), role: .cancel) { state.dismissPendingAttack() }
        } message: {
            Text(state.pendingAttackSummary)
        }
        .onChange(of: state.pendingServerDecision?.id, initial: true) { _, _ in
            let type = state.pendingServerDecision?.type
            showNativeTrade = (type == .nativeTrade)
            showDiplomacy = (type == .diplomacy)
            selectedLootTypes.removeAll()
            if type == .newLandName || type == .newRegionName {
                let defaultText = state.pendingTextPrompt?.defaultText ?? ""
                namePromptText = defaultText
            }
        }
        .onPreferenceChange(MapViewportKey.self) { info in
            mapViewport = info
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("Verbindung trennen", table: "GameView")) { state.disconnect() }
            }
        }
        } // End KeyboardShortcutHandlerView
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(L10n.text("Aktion fehlgeschlagen", table: "GameView"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                Spacer(minLength: 4)
                Button(L10n.text("Schließen", table: "GameView")) { state.clearError() }
                    .font(.caption)
                    .buttonStyle(.plain)
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityLabel(L10n.text("Fehler: \(message)", table: "GameView"))

            if let recoveryTitle = state.errorRecoveryActionTitle {
                Button(recoveryTitle) { state.performErrorRecoveryAction() }
                    .buttonStyle(.bordered)
                    .help(L10n.text("Behebt den bekannten Bewegungsfehler, sofern die Aktion weiterhin möglich ist.", table: "GameView"))
            }
        }
        .padding(10)
        .frame(maxWidth: 420, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var queuedActionsPanel: some View {
        if !state.queuedGameplayActions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("Ausstehende Aktionen – vor dem erneuten Senden prüfen", table: "GameView"))
                    .font(.caption.bold())
                ForEach(state.queuedGameplayActions) { action in
                    HStack {
                        Text(action.title)
                            .font(.caption)
                        Spacer()
                        Button(L10n.text("Erneut senden", table: "GameView")) {
                            queuedActionToConfirm = action
                            showQueuedActionConfirmation = true
                        }
                        .disabled(state.phase != .inGame)
                        Button(L10n.text("Verwerfen", table: "GameView")) {
                            state.discardQueuedGameplayAction(action)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.82))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .alert(L10n.text("Aktion erneut senden?", table: "GameView"), isPresented: $showQueuedActionConfirmation) {
                Button(L10n.text("Erneut senden", table: "GameView"), role: .destructive) {
                    if let action = queuedActionToConfirm {
                        state.resendQueuedGameplayAction(action)
                    }
                    queuedActionToConfirm = nil
                }
                Button(L10n.text("Abbrechen", table: "GameView"), role: .cancel) {
                    queuedActionToConfirm = nil
                }
            } message: {
                Text(L10n.text("Der Server könnte diese Aktion bereits vor dem Verbindungsabbruch verarbeitet haben.", table: "GameView"))
            }
        }
    }

    private var endTurnDialog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Zug beenden?", table: "GameView"))
                .font(.title3.bold())
            Text(L10n.text("Diese Einheiten haben noch keinen Befehl:", table: "GameView"))
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.unitsAwaitingOrders) { unit in
                        Button {
                            let tileId = state.game?.resolvedTileId(for: unit)
                            state.selectUnit(unit.id, onTile: tileId)
                            state.dismissEndTurnDialog()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(state.unitDisplayLabel(unit))
                                        .font(.caption)
                                    Text(state.unitLocationDisplayName(unit))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(L10n.text("\(unit.displayMovesLeft) Bewegungspunkte", table: "GameView"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
            HStack {
                Spacer()
                Button(L10n.text("Abbrechen", table: "GameView")) { state.dismissEndTurnDialog() }
                Button(L10n.text("Trotzdem beenden", table: "GameView")) { state.confirmEndTurn() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var defeatOverlay: some View {
        VStack(spacing: 14) {
            Text(L10n.text("Besiegt", table: "GameView"))
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(L10n.text("Deine Nation wurde ausgeschaltet.", table: "GameView"))
                .foregroundColor(.white)
            HStack(spacing: 12) {
                if !state.isUndead {
                    Button(L10n.text("Rachemodus starten", table: "GameView")) {
                        state.enterRevengeModeFromDefeat()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(L10n.text("Verbindung trennen", table: "GameView")) { state.disconnect() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .background(Color.black.opacity(0.88))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var victoryOverlay: some View {
        VStack(spacing: 14) {
            Text(L10n.text("Sieg!", table: "GameView"))
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(state.gameEndedHighScore
                 ? L10n.text("Du hast das Spiel mit einer Spitzenpunktzahl gewonnen.", table: "GameView")
                 : L10n.text("Du hast das Spiel gewonnen!", table: "GameView"))
                .foregroundColor(.white)
            HStack(spacing: 12) {
                Button(L10n.text("Weiterspielen", table: "GameView")) {
                    state.continueAfterVictory()
                }
                .buttonStyle(.borderedProminent)
                Button(L10n.text("Aufgeben", table: "GameView")) {
                    state.retireAfterVictory()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .background(Color.black.opacity(0.88))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Group {
                if let game = state.game {
                    let turnInfo = yearSeason(for: game.turn.number)
                    let date = turnInfo.season.map {
                        L10n.text("\($0) \(turnInfo.year)", table: "GameView")
                    } ?? L10n.text("Jahr \(turnInfo.year)", table: "GameView")
                    Text(L10n.text("R\(game.turn.number) · \(turnInfo.year)", table: "GameView"))
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .help(L10n.text("Runde \(game.turn.number), \(date)", table: "GameView"))
                        .accessibilityLabel(L10n.text("Runde \(game.turn.number), \(date)", table: "GameView"))
                    if let local = state.localPlayer {
                        resourceItem("\(local.gold)", systemImage: "dollarsign.circle.fill", help: L10n.text("Gold", table: "GameView"))
                        Text(L10n.text("Steuern \(local.tax)%", table: "GameView"))
                        Text(L10n.text("Freiheit \(local.liberty)", table: "GameView"))
                        if let required = local.immigrationRequired {
                            Text(L10n.text("Einwanderung \(local.immigration)/\(required)", table: "GameView"))
                        }
                    }
                }
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize()
            Spacer(minLength: 8)
            Button(L10n.text("Nächste Einheit", table: "GameView")) { state.selectNextUnit() }
                .disabled(state.cyclingLocalUnits.isEmpty)
                .help(L10n.text("Wählt die nächste eigene Einheit aus.", table: "GameView"))
            Button(L10n.text("Zug beenden", table: "GameView")) { state.requestEndTurn() }
                .buttonStyle(GameActionButtonStyle())
                .disabled(!state.canEndTurn)
                .help(L10n.text("Vor dem Zugende werden Einheiten ohne Befehl angezeigt.", table: "GameView"))
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.92))
    }

    private func resourceItem(_ value: String, systemImage: String, help: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
        .fixedSize()
        .help(help)
        .accessibilityLabel(L10n.text("\(help): \(value)", table: "GameView"))
    }

    private func shortcutLabel(_ title: String, description: String) -> String {
        guard let shortcut = state.keyboardShortcutsManager?.shortcuts.first(
            where: { $0.description == description }
        ) else { return title }
        return L10n.text("\(title) (\(shortcut.fullDisplay))", table: "GameView")
    }

    private func actionSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.top, 5)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func mapDecisionOverlay(for pending: GameState.PendingServerDecision) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.45)
                    .contentShape(Rectangle())
                    .onTapGesture {}

                ScrollView([.horizontal, .vertical]) {
                    Group {
                        switch pending.type {
                        case .foundingFather:
                            FoundingFatherSelectionView(
                                options: state.pendingFoundingFathers,
                                canChoose: state.canRespondToPendingDecision(),
                                onChoose: state.choosePendingFoundingFather
                            )
                            .frame(width: max(0, geometry.size.width - 32),
                                   height: max(360, geometry.size.height - 32))
                        case .nativeTrade where showNativeTrade:
                            NativeTradeView()
                                .frame(width: max(460, min(760, geometry.size.width - 32)))
                        case .diplomacy where showDiplomacy:
                            DiplomacyView(onClose: { showDiplomacy = false })
                                .frame(width: max(640, min(820, geometry.size.width - 32)),
                                       height: max(400, min(640, geometry.size.height - 32)))
                        default:
                            pendingDecisionView(for: pending)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(16)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityIdentifier("map-event-overlay")
        }
    }

    @ViewBuilder
    private func pendingDecisionView(for pending: GameState.PendingServerDecision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.pendingDecisionTitle)
                .font(.caption.bold())
                .foregroundColor(.white)
            
            // Show user-facing message for specific prompt types
            Group {
                switch pending.type {
                case .monarchAction:
                    Text(state.monarchActionMessage)
                case .firstContact:
                    Text(state.firstContactMessage)
                case .indianDemand:
                    Text(state.indianDemandMessage)
                default:
                    Text(state.pendingDecisionSummary)
                }
            }
            .font(.caption)
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)

            switch pending.type {
            case .indianDemand:
                HStack(spacing: 8) {
                    Button(L10n.text("Akzeptieren", table: "GameView")) { state.acceptPendingDecision() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Ablehnen", table: "GameView")) { state.declinePendingDecision() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .lootCargo:
                lootDecisionControls()
            case .fountainOfYouth:
                emigrantDecisionControls()
            case .firstContact:
                HStack(spacing: 8) {
                    Button(L10n.text("Kontakt herstellen", table: "GameView")) { state.acceptFirstContact() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Ablehnen", table: "GameView")) { state.declineFirstContact() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .monarchAction:
                HStack(spacing: 8) {
                    Button(L10n.text("Akzeptieren", table: "GameView")) { state.answerMonarch(accept: true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Ablehnen", table: "GameView")) { state.answerMonarch(accept: false) }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .newLandName, .newRegionName:
                nameDecisionControls()
            case .nativeTrade:
                HStack(spacing: 8) {
                    Button(L10n.text("Handel öffnen", table: "GameView")) { showNativeTrade = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Schließen", table: "GameView")) { state.closeNativeTrade() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .nativeSkill:
                HStack(spacing: 8) {
                    Button(L10n.text("Fähigkeit erlernen", table: "GameView")) { state.acceptPendingNativeSkill() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Abbrechen", table: "GameView")) { state.declinePendingNativeSkill() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .diplomacy:
                HStack(spacing: 8) {
                    Button(L10n.text("Prüfen", table: "GameView")) { showDiplomacy = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Ablehnen", table: "GameView")) { state.rejectDiplomacy() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .foundingFather:
                EmptyView()
            case .scoutReport:
                Button(L10n.text("OK", table: "GameView")) { state.acknowledgePendingDecision() }
                    .buttonStyle(.borderedProminent)
            case .incite:
                HStack(spacing: 8) {
                    Button(L10n.text("Bestätigen", table: "GameView")) { state.confirmPendingIncite() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button(L10n.text("Ablehnen", table: "GameView")) { state.declinePendingIncite() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            }
        }
        .padding(10)
        .frame(maxWidth: 300)
        .background(Color.black.opacity(0.68))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func lootDecisionControls() -> some View {
        let options = state.pendingLootOptions
        if options.isEmpty {
            Text(L10n.text("Keine Fracht verfügbar.", table: "GameView"))
                .font(.caption2)
                .foregroundColor(.secondary)
            Button(L10n.text("Nichts nehmen", table: "GameView")) { state.lootPendingCargo(selected: []) }
                .buttonStyle(.bordered)
        } else {
            ForEach(options) { option in
                Toggle(isOn: Binding(
                    get: { selectedLootTypes.contains(option.type) },
                    set: { isOn in
                        if isOn { selectedLootTypes.insert(option.type) }
                        else { selectedLootTypes.remove(option.type) }
                    }
                )) {
                    Text(L10n.text("\(state.goodsDisplayName(option.type)) ×\(option.amount)", table: "GameView"))
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .toggleStyle(.checkbox)
            }
            HStack(spacing: 8) {
                Button(L10n.text("Ausgewählte nehmen", table: "GameView")) {
                    state.lootPendingCargo(selected: options.filter { selectedLootTypes.contains($0.type) })
                    selectedLootTypes.removeAll()
                }
                .buttonStyle(.borderedProminent)
                Button(L10n.text("Nichts nehmen", table: "GameView")) {
                    state.lootPendingCargo(selected: [])
                    selectedLootTypes.removeAll()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func emigrantDecisionControls() -> some View {
        let options = state.pendingEmigrantOptions
        if options.isEmpty {
            Text(L10n.text("Keine Auswanderer verfügbar.", table: "GameView"))
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            ForEach(options) { option in
                Button {
                    state.emigratePendingMigrant(slot: option.slot)
                } label: {
                    Text(L10n.text("\(option.unitType.map(state.unitDisplayName) ?? L10n.text("Einheit", table: "GameView")) platzieren", table: "GameView"))
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .disabled(!state.canRespondToPendingDecision())
            }
        }
    }

    @ViewBuilder
    private func nameDecisionControls() -> some View {
        let defaultText = state.pendingTextPrompt?.defaultText ?? ""
        VStack(alignment: .leading, spacing: 6) {
            TextField(L10n.text("Name", table: "GameView"), text: $namePromptText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onAppear { namePromptText = defaultText }
                .onChange(of: defaultText) { _, newValue in namePromptText = newValue }
            HStack(spacing: 8) {
                Button(L10n.text("Bestätigen", table: "GameView")) {
                    guard let type = state.pendingServerDecision?.type else { return }
                    if type == .newLandName {
                        state.submitNewLandName(namePromptText)
                    } else {
                        state.submitNewRegionName(namePromptText)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !state.canRespondToPendingDecision() ||
                        namePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private var independenceSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Unabhängigkeit erklären", table: "GameView"))
                .font(.title3.bold())
            HStack {
                Text(L10n.text("Land:", table: "GameView"))
                    .frame(width: 70, alignment: .trailing)
                TextField(L10n.text("Land", table: "GameView"), text: $independenceCountry)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text(L10n.text("Nation:", table: "GameView"))
                    .frame(width: 70, alignment: .trailing)
                TextField(L10n.text("Nation", table: "GameView"), text: $independenceNation)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button(L10n.text("Abbrechen", table: "GameView")) { state.showIndependencePanel = false }
                Button(L10n.text("Erklären", table: "GameView")) {
                    state.declareIndependence(countryName: independenceCountry,
                                              nationName: independenceNation)
                    state.showIndependencePanel = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(independenceCountry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private var findSettlementSheet: some View {
        let colonies = (state.game.map { Array($0.colonies.values) } ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Siedlung suchen", table: "GameView"))
                .font(.title3.bold())
            TextField(L10n.text("Suchen", table: "GameView"), text: $findSettlementQuery)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(colonies.filter {
                        findSettlementQuery.isEmpty
                            || ($0.name ?? "").localizedCaseInsensitiveContains(findSettlementQuery)
                    }) { colony in
                        Button {
                            if let tileId = colony.tileId {
                                state.requestMapScroll(to: tileId)
                            }
                            state.showFindSettlementPanel = false
                        } label: {
                            HStack {
                                Text(colony.name ?? "?")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(state.game?.players[colony.owner ?? ""]?.name ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button(L10n.text("Schließen", table: "GameView")) { state.showFindSettlementPanel = false }
            }
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 320)
    }

    /// Compact floating action card for the selected unit (Java quick-actions equivalent).
    private var unitQuickActions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if state.selectedUnit != nil {
                    InfoPanelView()
                    Divider()

                    Button(L10n.text("Bewegen…", table: "GameView")) { state.beginChoosingMoveDestination() }
                        .buttonStyle(.borderedProminent)
                        .help(state.selectedUnitMoveDisabledReason
                              ?? L10n.text("Wählt ein Zielfeld per Linksklick. Alternativ bewegt ein Rechtsklick auf ein Feld die Einheit direkt.", table: "GameView"))
                        .disabled(!state.canChooseMoveDestination)

                    if let tileId = state.selectedTileId,
                        state.canMoveSelectedUnitTo(destinationTileId: tileId)
                    {
                        Button(L10n.text("Zum ausgewählten Feld", table: "GameView")) {
                            state.moveSelectedUnitTo(destinationTileId: tileId)
                        }
                    }

                    if state.selectedColony != nil {
                        Button(shortcutLabel(L10n.text("Kolonie öffnen", table: "GameView"), description: L10n.text("Kolonie-Panel öffnen", table: "GameView"))) {
                            state.openColonyPanel()
                        }
                    }

                    actionSectionTitle(L10n.text("Einheitenbefehle", table: "GameView"))
                    Button(shortcutLabel(L10n.text("Aktivieren", table: "GameView"), description: L10n.text("Einheit aktivieren", table: "GameView"))) {
                        state.setSelectedUnitState(.active)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .active))
                    .help(state.canChangeSelectedUnitState(to: .active)
                          ? L10n.text("Einheit wieder für Befehle aktivieren.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel(L10n.text("Warten", table: "GameView"), description: L10n.text("Warten / Überspringen", table: "GameView"))) {
                        state.setSelectedUnitState(.skipped)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                    .help(state.canChangeSelectedUnitState(to: .skipped)
                          ? L10n.text("Einheit bis zu einem späteren Zug überspringen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel(L10n.text("Wache", table: "GameView"), description: L10n.text("Wache halten", table: "GameView"))) {
                        state.setSelectedUnitState(.sentry)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                    .help(state.canChangeSelectedUnitState(to: .sentry)
                          ? L10n.text("Einheit in Verteidigungsbereitschaft versetzen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel(L10n.text("Befestigen", table: "GameView"), description: L10n.text("Befestigen", table: "GameView"))) {
                        state.setSelectedUnitState(.fortifying)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                    .help(state.canChangeSelectedUnitState(to: .fortifying)
                          ? L10n.text("Einheit befestigen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    if !state.selectedUnitImprovementCandidates.isEmpty {
                        actionSectionTitle(L10n.text("Pionierarbeit", table: "GameView"))
                        ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                            Button(L10n.text("\(candidate.label) bauen", table: "GameView")) {
                                state.changeSelectedUnitWorkImprovement(candidate.id)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canChangeSelectedUnitWorkImprovement)
                        }
                    }

                    Button(shortcutLabel(L10n.text("Befehle löschen", table: "GameView"), description: L10n.text("Befehle löschen", table: "GameView"))) {
                        state.clearSelectedUnitOrders()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canClearSelectedUnitOrders)
                    .help(state.canClearSelectedUnitOrders
                          ? L10n.text("Marschziel und Einheitenstatus zurücksetzen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    if state.showsEuropeTravelOrder {
                        Button(L10n.text("Gehe nach Europa", table: "GameView")) { state.goSelectedShipToEurope() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canGoSelectedShipToEurope)
                    }

                    Button(L10n.text("Einheit auflösen…", table: "GameView"), role: .destructive) {
                        state.disbandSelectedUnit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canDisbandSelectedUnit)
                    .help(state.selectedUnitDisbandDisabledReason
                          ?? L10n.text("Einheit dauerhaft aus dem Spiel entfernen.", table: "GameView"))

                    if state.canBuildSelectedColony {
                        actionSectionTitle(L10n.text("Kolonie", table: "GameView"))
                        TextField(L10n.text("Koloniename", table: "GameView"), text: $colonyName)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { colonyName = state.suggestedColonyName }
                            .onChange(of: state.selectedUnitId) { _, _ in
                                colonyName = state.suggestedColonyName
                            }
                        Button(shortcutLabel(L10n.text("Kolonie gründen", table: "GameView"), description: L10n.text("Kolonie bauen", table: "GameView"))) {
                            state.buildColony(name: colonyName)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(colonyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if state.canJoinSelectedColony {
                        actionSectionTitle(L10n.text("Kolonie", table: "GameView"))
                        Button(shortcutLabel(L10n.text("In der Kolonie arbeiten", table: "GameView"), description: L10n.text("In der Kolonie arbeiten", table: "GameView"))) {
                            state.joinSelectedColony()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.embarkCarrierOptions.isEmpty {
                        actionSectionTitle(L10n.text("Transport", table: "GameView"))
                        ForEach(state.embarkCarrierOptions, id: \.id) { carrier in
                            Button(shortcutLabel(L10n.text("An Bord: \(carrier.unitType.map(state.unitDisplayName) ?? L10n.text("Transporter", table: "GameView"))", table: "GameView"),
                                                description: L10n.text("An Bord gehen", table: "GameView"))) {
                                state.embarkSelectedUnit(onCarrier: carrier.id)
                            }
                            .disabled(!state.canEmbarkSelectedUnit(onCarrier: carrier.id))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if state.selectedUnitCarrier != nil {
                        actionSectionTitle(L10n.text("Transport", table: "GameView"))
                        Button(shortcutLabel(L10n.text("Von Bord gehen", table: "GameView"), description: L10n.text("Von Bord gehen", table: "GameView"))) {
                            state.disembarkSelectedUnit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canDisembarkSelectedUnit)
                        if let hint = state.selectedUnitDisembarkHint {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let targetTileId = state.selectedTileId,
                        state.canAttackSelectedUnitMelee(onTile: targetTileId)
                            || state.canAttackSelectedUnitRanged(onTile: targetTileId)
                    {
                        actionSectionTitle(L10n.text("Angriff", table: "GameView"))
                        Button(shortcutLabel(L10n.text("Nahkampf", table: "GameView"), description: L10n.text("Nahkampf", table: "GameView"))) {
                            state.requestAttack(onTile: targetTileId, ranged: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitMelee(onTile: targetTileId))
                        .help(state.canAttackSelectedUnitMelee(onTile: targetTileId)
                              ? L10n.text("Das ausgewählte Feld im Nahkampf angreifen.", table: "GameView")
                              : state.selectedUnitActionUnavailableReason)

                        Button(shortcutLabel(L10n.text("Fernkampf", table: "GameView"), description: L10n.text("Fernkampf", table: "GameView"))) {
                            state.requestAttack(onTile: targetTileId, ranged: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitRanged(onTile: targetTileId))
                        .help(state.canAttackSelectedUnitRanged(onTile: targetTileId)
                              ? L10n.text("Das ausgewählte Feld im Fernkampf angreifen.", table: "GameView")
                              : state.selectedUnitActionUnavailableReason)
                    }

                    actionSectionTitle(L10n.text("Marschziel", table: "GameView"))
                    Button(L10n.text("Ausgewähltes Feld als Ziel", table: "GameView")) {
                        if let tileId = state.selectedTileId {
                            state.setSelectedUnitDestination(to: tileId)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canSetDestinationToSelectedTile)
                    .help(state.canSetDestinationToSelectedTile
                          ? L10n.text("Das ausgewählte Kartenfeld als Marschziel festlegen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    Button(L10n.text("Ziel löschen", table: "GameView")) {
                        state.clearSelectedUnitDestination()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canClearSelectedUnitDestination)
                    .help(state.canClearSelectedUnitDestination
                          ? L10n.text("Das gespeicherte Marschziel entfernen.", table: "GameView")
                          : state.selectedUnitActionUnavailableReason)

                    if !state.selectedUnitRoleEquipmentOptions.isEmpty {
                        actionSectionTitle(L10n.text("Ausrüstung", table: "GameView"))
                        ForEach(state.selectedUnitRoleEquipmentOptions) { option in
                            Button(option.buttonTitle) {
                                state.equipSelectedUnitForRole(option.roleId, count: option.count)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!option.isAvailable)
                            .help(option.helpText)
                        }
                    }

                    if !state.selectedUnitCargoUnits.isEmpty {
                        actionSectionTitle(L10n.text("Passagiere", table: "GameView"))
                        ForEach(state.selectedUnitCargoUnits, id: \.id) { cargo in
                            Button(L10n.text("Auswählen: \(cargo.unitType.map(state.unitDisplayName) ?? L10n.text("Einheit", table: "GameView"))", table: "GameView")) {
                                let tileId = state.selectedUnitTileId
                                state.selectUnit(
                                    cargo.id,
                                    onTile: tileId.flatMap { state.game?.tiles[$0] != nil ? $0 : nil })
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !state.selectedUnitCargoGoods.isEmpty {
                        actionSectionTitle(L10n.text("Ladung", table: "GameView"))
                        ForEach(state.selectedUnitCargoGoods, id: \.id) { item in
                            HStack {
                                Text(L10n.text("\(item.label): \(item.amount)", table: "GameView"))
                                Spacer()
                                Button(role: .destructive) {
                                    state.dumpSelectedUnitCargo(typeId: item.id, amount: item.amount)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .help(L10n.text("\(item.label) abwerfen", table: "GameView"))
                                .accessibilityLabel(L10n.text("\(item.label) abwerfen", table: "GameView"))
                            }
                        }
                    }

                    if !state.nativeTradeTargetsForSelectedUnit.isEmpty {
                        actionSectionTitle(L10n.text("Ureinwohner-Siedlung", table: "GameView"))
                        ForEach(state.nativeTradeTargetsForSelectedUnit) { target in
                            Menu(target.name) {
                                Button(L10n.text("Handeln…", table: "GameView")) {
                                    state.openNativeTradeWithSelectedUnit(settlementId: target.settlementId)
                                }
                                .disabled(!state.canOpenNativeTrade)

                                Menu(L10n.text("Geschenk überbringen", table: "GameView")) {
                                    ForEach(state.selectedUnitCargoGoods, id: \.id) { goods in
                                        Button(L10n.text("\(goods.label) (\(goods.amount))", table: "GameView")) {
                                            state.deliverGiftToSettlement(
                                                target.settlementId,
                                                goodsType: goods.id,
                                                amount: goods.amount
                                            )
                                        }
                                    }
                                }
                                .disabled(!state.canDeliverGiftWithSelectedUnit || state.selectedUnitCargoGoods.isEmpty)

                                Button(L10n.text("Tribut fordern", table: "GameView")) {
                                    if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                        state.demandTributeFromSettlement(direction: direction)
                                    }
                                }
                                .disabled(
                                    !state.canDemandTributeWithSelectedUnit
                                        || state.directionToAdjacentSettlement(target.settlementId) == nil)

                                Button(L10n.text("Siedlung erkunden", table: "GameView")) {
                                    if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                        state.scoutIndianSettlement(direction: direction)
                                    }
                                }
                                .disabled(
                                    !state.canScoutIndianSettlement
                                        || state.directionToAdjacentSettlement(target.settlementId) == nil)

                                Button(L10n.text("Mit Häuptling sprechen", table: "GameView")) {
                                    state.scoutSpeakToChief(settlementId: target.settlementId)
                                }
                                .disabled(
                                    !state.canScoutSpeakToChief
                                        || state.directionToAdjacentSettlement(target.settlementId) == nil)

                                Button(L10n.text("Fähigkeit erlernen…", table: "GameView")) {
                                    if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                        state.beginNativeSkillLearning(
                                            settlementId: target.settlementId,
                                            direction: direction
                                        )
                                    }
                                }
                                .disabled(
                                    !state.canLearnSkillAtSelectedUnit
                                        || state.directionToAdjacentSettlement(target.settlementId) == nil)

                                Menu(L10n.text("Aufstand anzetteln…", table: "GameView")) {
                                    ForEach(state.diplomacyVictimOptions(), id: \.id) { victim in
                                        Button(victim.label) {
                                            state.inciteSettlement(
                                                settlementId: target.settlementId,
                                                enemyPlayerId: victim.id)
                                        }
                                    }
                                }
                                .disabled(!state.canInciteSelectedUnit)
                            }
                            .font(.caption)
                            .fixedSize()
                        }
                    }

                    if !state.diplomacyInitiationTargetsForSelectedUnit.isEmpty {
                        Menu(state.diplomacyContextForSelectedUnit == "TRIBUTE" ? L10n.text("Tribut verhandeln…", table: "GameView") : L10n.text("Diplomatie…", table: "GameView")) {
                            ForEach(state.diplomacyInitiationTargetsForSelectedUnit, id: \.id) { target in
                                Button(target.label) {
                                    state.beginDiplomacy(otherColonyId: target.id)
                                }
                            }
                        }
                        .font(.caption)
                        .fixedSize()
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(GameActionButtonStyle(fillsAvailableWidth: true))
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func yearSeason(for turn: Int) -> (year: Int, season: String?) {
        // Java-like calculation (Turn.java): starting year 1492, seasons split in 1600.
        let raw = turn - 1 + 1492
        if raw < 1600 {
            return (raw, nil)
        }
        let delta = raw - 1600
        return (1600 + delta / 2, delta % 2 == 0 ? L10n.text("Frühling", table: "GameView") : L10n.text("Herbst", table: "GameView"))
    }
}

private struct GameActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let fillsAvailableWidth: Bool

    init(fillsAvailableWidth: Bool = false) {
        self.fillsAvailableWidth = fillsAvailableWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(
                maxWidth: fillsAvailableWidth ? .infinity : nil,
                minHeight: fillsAvailableWidth ? 36 : nil,
                alignment: .leading
            )
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background(
                isEnabled
                    ? Color.blue.opacity(configuration.isPressed ? 0.7 : 1)
                    : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isEnabled ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
            }
    }
}
