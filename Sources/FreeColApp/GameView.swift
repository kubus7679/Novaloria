import SwiftUI
import FreeColClient
import FreeColGame

struct GameView: View {
    @Environment(GameState.self) private var state

    @State private var colonyName: String = "New Amsterdam"
    @State private var mapViewport: MapViewportInfo?
    @State private var selectedLootTypes: Set<String> = []
    @State private var namePromptText: String = ""
    @State private var showReports = false
    @State private var showNativeTrade = false
    @State private var showDiplomacy = false
    @State private var showChat = false
    @State private var showPreferences = false
    @State private var showColopedia = false
    @State private var showIndependence = false
    @State private var independenceCountry = "United States"
    @State private var independenceNation = "America"
    @State private var showFindSettlement = false
    @State private var findSettlementQuery = ""
    @State private var showTradeRoutes = false
    @State private var queuedActionToConfirm: GameState.QueuedGameplayAction?
    @State private var showQueuedActionConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                topBar
            }
            .fixedSize(horizontal: false, vertical: true)

            if let pending = state.pendingServerDecision {
                if pending.type == .foundingFather {
                    FoundingFatherSelectionView(
                        options: state.pendingFoundingFathers,
                        canChoose: state.canRespondToPendingDecision(),
                        onChoose: state.choosePendingFoundingFather
                    )
                } else {
                    ScrollView {
                        pendingDecisionView(for: pending)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .frame(maxHeight: 180)
                    .clipped()
                }
            }
            if !state.queuedGameplayActions.isEmpty {
                ScrollView { queuedActionsPanel }
                    .frame(maxHeight: 130)
            }
            if let err = state.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.85))
                    .onTapGesture { state.errorMessage = nil }
            }
            if state.isChoosingMoveDestination {
                HStack {
                    Text("Bewegen: Zielfeld auf der Karte anklicken.")
                    Spacer()
                    Button("Abbrechen") { state.cancelChoosingMoveDestination() }
                        .keyboardShortcut(.cancelAction)
                }
                .font(.callout)
                .padding(8)
                .background(Color.accentColor.opacity(0.2))
            }

            HStack(spacing: 0) {
                MapView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Divider()
                if state.selectedUnit != nil {
                    unitQuickActions
                        .frame(width: 260)
                } else {
                    ScrollView { InfoPanelView() }
                        .frame(width: 260)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack(spacing: 12) {
                MiniMapView(viewport: mapViewport, minimapWidth: 140, maxMiniHeight: 72)
                    .frame(width: 140, height: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.turnStatusDescription)
                        .font(.headline)
                    Text("\(state.unitsAwaitingOrders.count) Einheiten ohne Befehl")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Zugbericht (\(state.localPlayerModelMessages.count))") {
                        state.requestedReport = .turn
                        showReports = true
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack {
                        Button("Kolonie") { state.openColonyPanel() }
                            .disabled(state.selectedColony == nil)
                        Button("Nächste Einheit") { state.selectNextUnit() }
                            .disabled(state.selectableLocalUnits.isEmpty)
                    }
                    Button("Zug beenden") { state.requestEndTurn() }
                        .buttonStyle(GameActionButtonStyle())
                        .disabled(!state.canEndTurn)
                        .help("Vor dem Zugende werden Einheiten ohne Befehl angezeigt.")
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
                        Text(selectedColony.name ?? "Colony")
                            .font(.title.bold())
                        Spacer()
                        Button("Schließen") { state.closeColonyPanel() }
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
                        onWorkAtLocation: { workLocationId in
                            state.assignSelectedColonyWorker(to: workLocationId)
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
                        onLoadGoods: { typeId, amount in
                            state.loadGoodsForSelectedColony(typeId: typeId, amount: amount)
                        },
                        onUnloadGoods: { typeId, amount in
                            state.unloadGoodsFromSelectedCarrier(typeId: typeId, amount: amount)
                        },
                        buildableCandidates: state.selectedColonyBuildableCandidates,
                        buildings: state.selectedColonyBuildings,
                        currentBuildQueue: state.selectedColonyBuildQueue,
                        buildingLabel: { state.buildingDisplayName($0) },
                        storedGoods: state.selectedColonyStoredGoods,
                        buildTargetLabel: state.selectedColonyBuildTarget?.label,
                        buildRequirements: state.selectedColonyBuildRequirements,
                        buildETATurns: state.selectedColonyEstimatedBuildTurns,
                        estimatedBuildPerTurn: state.selectedColonyEstimatedBuildPerTurn,
                        estimatedProduction: state.selectedColonyEstimatedProduction
                    )
                }
                .frame(
                    minWidth: 640, idealWidth: 820, maxWidth: 1100,
                    minHeight: 400, idealHeight: 640, maxHeight: 760)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { state.showDebugPanel },
                set: { state.showDebugPanel = $0 }
            )
        ) {
            VStack(spacing: 0) {
                HStack {
                    Text("Debug").font(.headline)
                    Spacer()
                    Button("Close") { state.closeDebugPanel() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding()
                Divider()
                DebugControlsView()
            }
            .frame(minWidth: 520, idealWidth: 640,
                   minHeight: 400, idealHeight: 640, maxHeight: 760)
        }
        .sheet(isPresented: $showReports) {
            ReportPanelView()
        }
        .sheet(isPresented: $showNativeTrade) {
            NativeTradeView()
        }
        .sheet(isPresented: $showDiplomacy) {
            DiplomacyView()
        }
        .sheet(isPresented: $showChat) {
            ChatPanelView()
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showColopedia) {
            ColopediaView()
        }
        .sheet(isPresented: Binding(
            get: { state.showStatusPanel },
            set: { state.showStatusPanel = $0 }
        )) {
            StatusPanelView()
        }
        .sheet(isPresented: $showIndependence) {
            independenceSheet
        }
        .sheet(isPresented: $showFindSettlement) {
            findSettlementSheet
        }
        .sheet(isPresented: $showTradeRoutes) {
            TradeRoutePanelView()
        }
        .sheet(isPresented: Binding(
            get: { state.showEndTurnDialog },
            set: { if !$0 { state.dismissEndTurnDialog() } }
        )) {
            endTurnDialog
        }
        .confirmationDialog(
            "Confirm Attack",
            isPresented: Binding(
                get: { state.showAttackConfirmation },
                set: { if !$0 { state.dismissPendingAttack() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Attack", role: .destructive) { state.confirmPendingAttack() }
            Button("Cancel", role: .cancel) { state.dismissPendingAttack() }
        } message: {
            Text(state.pendingAttackSummary)
        }
        .onChange(of: state.pendingServerDecision?.type) { _, newType in
            showNativeTrade = (newType == .nativeTrade)
            showDiplomacy = (newType == .diplomacy)
            if newType == .newLandName || newType == .newRegionName {
                namePromptText = state.pendingTextPrompt?.defaultText ?? ""
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
        .overlay {
            if state.isDefeated {
                defeatOverlay
            } else if state.isVictorious {
                victoryOverlay
            }
        }
    }

    @ViewBuilder
    private var queuedActionsPanel: some View {
        if !state.queuedGameplayActions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pending actions — review before resending")
                    .font(.caption.bold())
                ForEach(state.queuedGameplayActions) { action in
                    HStack {
                        Text(action.title)
                            .font(.caption)
                        Spacer()
                        Button("Send again") {
                            queuedActionToConfirm = action
                            showQueuedActionConfirmation = true
                        }
                        .disabled(state.phase != .inGame)
                        Button("Discard") {
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
            .alert("Send action again?", isPresented: $showQueuedActionConfirmation) {
                Button("Send again", role: .destructive) {
                    if let action = queuedActionToConfirm {
                        state.resendQueuedGameplayAction(action)
                    }
                    queuedActionToConfirm = nil
                }
                Button("Cancel", role: .cancel) {
                    queuedActionToConfirm = nil
                }
            } message: {
                Text("The server may already have processed this action before the connection was lost.")
            }
        }
    }

    private var endTurnDialog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zug beenden?")
                .font(.title3.bold())
            Text("Diese Einheiten haben noch keinen Befehl:")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.unitsAwaitingOrders) { unit in
                        Button {
                            let tileId = unit.location.flatMap {
                                state.game?.tiles[$0] != nil ? $0 : nil
                            }
                            state.selectUnit(unit.id, onTile: tileId)
                            state.dismissEndTurnDialog()
                        } label: {
                            HStack {
                                Text(unit.unitType.map(state.unitDisplayName) ?? "Einheit")
                                    .font(.caption)
                                Spacer()
                                Text("\(unit.movesLeft) Bewegungspunkte")
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
                Button("Abbrechen") { state.dismissEndTurnDialog() }
                Button("Trotzdem beenden") { state.confirmEndTurn() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var defeatOverlay: some View {
        VStack(spacing: 14) {
            Text("Defeated")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Your nation has been eliminated.")
                .foregroundColor(.white)
            HStack(spacing: 12) {
                if !state.isUndead {
                    Button("Enter Revenge Mode") {
                        state.enterRevengeModeFromDefeat()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Verbindung trennen") { state.disconnect() }
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
            Text("Victory!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(state.gameEndedHighScore
                 ? "You won the game with a high score."
                 : "You won the game!")
                .foregroundColor(.white)
            HStack(spacing: 12) {
                Button("Continue Playing") {
                    state.continueAfterVictory()
                }
                .buttonStyle(.borderedProminent)
                Button("Retire") {
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
        HStack(spacing: 12) {
            GameMenuBar(
                onChat: { showChat = true },
                onReports: { showReports = true },
                onPreferences: { showPreferences = true },
                onColopedia: { showColopedia = true },
                onIndependence: { showIndependence = true },
                onFindSettlement: { showFindSettlement = true },
                onTradeRoutes: { showTradeRoutes = true }
            )
            Divider().frame(height: 18)
            if let game = state.game {
                let turnInfo = yearSeason(for: game.turn.number)
                Text("Runde \(game.turn.number)")
                    .font(.headline)
                if let season = turnInfo.season {
                    Text("\(season) \(turnInfo.year)")
                        .font(.caption)
                } else {
                    Text("Jahr \(String(turnInfo.year))")
                        .font(.caption)
                }
                if let local = state.localPlayer {
                    Text("Gold: \(local.gold)")
                    Text("Steuern: \(local.tax)%")
                    Text("Punkte: \(local.score)")
                }
            }
            Spacer()
            if state.highScoresReport != nil || state.nationSummaryReport != nil {
                Button("Berichte") { showReports = true }
                    .font(.caption)
            }
            if !state.statusMessage.isEmpty, state.pendingServerDecision == nil {
                Text(state.statusMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.92))
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
                    Button("Akzeptieren") { state.acceptPendingDecision() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Ablehnen") { state.declinePendingDecision() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .lootCargo:
                lootDecisionControls()
            case .fountainOfYouth:
                emigrantDecisionControls()
            case .firstContact:
                HStack(spacing: 8) {
                    Button("Kontakt herstellen") { state.acceptFirstContact() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Ablehnen") { state.declineFirstContact() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .monarchAction:
                HStack(spacing: 8) {
                    Button("Akzeptieren") { state.answerMonarch(accept: true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Ablehnen") { state.answerMonarch(accept: false) }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .newLandName, .newRegionName:
                nameDecisionControls()
            case .nativeTrade:
                HStack(spacing: 8) {
                    Button("Handel öffnen") { showNativeTrade = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Schließen") { state.closeNativeTrade() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .diplomacy:
                HStack(spacing: 8) {
                    Button("Prüfen") { showDiplomacy = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Ablehnen") { state.rejectDiplomacy() }
                        .buttonStyle(.bordered)
                        .disabled(!state.canRespondToPendingDecision())
                }
            case .foundingFather:
                EmptyView()
            case .scoutReport:
                Button("OK") { state.acknowledgePendingDecision() }
                    .buttonStyle(.borderedProminent)
            case .incite:
                HStack(spacing: 8) {
                    Button("Bestätigen") { state.confirmPendingIncite() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canRespondToPendingDecision())
                    Button("Ablehnen") { state.declinePendingIncite() }
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
            Text("No cargo available.")
                .font(.caption2)
                .foregroundColor(.secondary)
            Button("Loot nothing") { state.lootPendingCargo(selected: []) }
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
                    Text("\(shortName(option.type, prefix: "model.goods.")) x\(option.amount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .toggleStyle(.checkbox)
            }
            HStack(spacing: 8) {
                Button("Take selected") {
                    state.lootPendingCargo(selected: options.filter { selectedLootTypes.contains($0.type) })
                    selectedLootTypes.removeAll()
                }
                .buttonStyle(.borderedProminent)
                Button("Take none") {
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
            Text("No emigrants available.")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            ForEach(options) { option in
                Button {
                    state.emigratePendingMigrant(slot: option.slot)
                } label: {
                    Text("Place \(shortName(option.unitType, prefix: "model.unit."))")
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
            TextField("Name", text: $namePromptText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onAppear { namePromptText = defaultText }
                .onChange(of: defaultText) { _, newValue in namePromptText = newValue }
            HStack(spacing: 8) {
                Button("Confirm") {
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

    private func shortName(_ value: String?, prefix: String) -> String {
        guard let value else { return "?" }
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }

    private func shortUnitName(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.split(separator: ".").last.map(String.init) ?? value
    }

    private var independenceSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Declare Independence")
                .font(.title3.bold())
            HStack {
                Text("Country:")
                    .frame(width: 70, alignment: .trailing)
                TextField("Country", text: $independenceCountry)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Nation:")
                    .frame(width: 70, alignment: .trailing)
                TextField("Nation", text: $independenceNation)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { showIndependence = false }
                Button("Declare") {
                    state.declareIndependence(countryName: independenceCountry,
                                              nationName: independenceNation)
                    showIndependence = false
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
            Text("Siedlung suchen")
                .font(.title3.bold())
            TextField("Suchen", text: $findSettlementQuery)
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
                            showFindSettlement = false
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
                Button("Schließen") { showFindSettlement = false }
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

                    Button("Bewegen…") { state.beginChoosingMoveDestination() }
                        .buttonStyle(GameActionButtonStyle())
                        .disabled(!state.canChooseMoveDestination)

                    if let tileId = state.selectedTileId,
                        state.canMoveSelectedUnitTo(destinationTileId: tileId)
                    {
                        Button("Zum ausgewählten Feld") {
                            state.moveSelectedUnitTo(destinationTileId: tileId)
                        }

                        .buttonStyle(.bordered)
                    }

                    if state.selectedColony != nil {
                        Button("Kolonie öffnen") { state.openColonyPanel() }
                            .buttonStyle(.bordered)
                    }

                    Menu("Befehle") {
                        Button("Warten") { state.setSelectedUnitState(.skipped) }
                            .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                        Button("Wache") { state.setSelectedUnitState(.sentry) }
                            .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                        Button("Befestigen") { state.setSelectedUnitState(.fortifying) }
                            .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                        Button("Befehle löschen") { state.clearSelectedUnitOrders() }
                            .disabled(!state.canClearSelectedUnitOrders)
                        Button("Nach Europa") { state.sendSelectedUnitToEurope() }
                            .disabled(!state.canSendSelectedUnitToEurope)
                        Divider()
                        Button("Einheit auflösen…", role: .destructive) {
                            state.disbandSelectedUnit()
                        }
                        .disabled(!state.canDisbandSelectedUnit)
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.vertical, 6)

                    Button("Aktivieren") {
                        state.setSelectedUnitState(.active)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .active))

                    if state.canBuildSelectedColony {
                        TextField("Koloniename", text: $colonyName)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { colonyName = state.suggestedColonyName }
                            .onChange(of: state.selectedUnitId) { _, _ in
                                colonyName = state.suggestedColonyName
                            }
                        Button("Kolonie gründen") {
                            state.buildColony(name: colonyName)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(colonyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if state.canJoinSelectedColony {
                        Button("In der Kolonie arbeiten") {
                            state.joinSelectedColony()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.embarkCarrierOptions.isEmpty {
                        ForEach(state.embarkCarrierOptions, id: \.id) { carrier in
                            Button("An Bord: \(carrier.unitType.map(state.unitDisplayName) ?? "Transporter")") {
                                state.embarkSelectedUnit(onCarrier: carrier.id)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if state.canDisembarkSelectedUnit {
                        Button("Von Bord gehen") {
                            state.disembarkSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let targetTileId = state.selectedTileId,
                        state.canAttackSelectedUnitMelee(onTile: targetTileId)
                            || state.canAttackSelectedUnitRanged(onTile: targetTileId)
                    {
                        Button("Nahkampf") {
                            state.requestAttack(onTile: targetTileId, ranged: false)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitMelee(onTile: targetTileId))

                        Button("Fernkampf") {
                            state.requestAttack(onTile: targetTileId, ranged: true)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitRanged(onTile: targetTileId))
                    }

                    Button("Ausgewähltes Feld als Ziel") {
                        if let tileId = state.selectedTileId {
                            state.setSelectedUnitDestination(to: tileId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canSetDestinationToSelectedTile)

                    Button("Ziel löschen") {
                        state.clearSelectedUnitDestination()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canClearSelectedUnitDestination)

                    if state.canEquipSelectedUnitForRole {
                        Button("Als Missionar ausrüsten") {
                            state.equipSelectedUnitForRole("model.role.missionary", count: 1)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.selectedUnitCargoUnits.isEmpty {
                        Text("Passagiere")
                            .font(.caption.bold())
                        ForEach(state.selectedUnitCargoUnits, id: \.id) { cargo in
                            Button("Auswählen: \(cargo.unitType.map(state.unitDisplayName) ?? "Einheit")") {
                                let tileId = state.selectedUnit?.location
                                state.selectUnit(
                                    cargo.id,
                                    onTile: tileId.flatMap { state.game?.tiles[$0] != nil ? $0 : nil })
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !state.selectedUnitCargoGoods.isEmpty {
                        Text("Ladung")
                            .font(.caption.bold())
                        ForEach(state.selectedUnitCargoGoods, id: \.id) { item in
                            HStack {
                                Text("\(item.label): \(item.amount)")
                                Spacer()
                                Menu {
                                    Button("Ladung abwerfen…", role: .destructive) {
                                        state.dumpSelectedUnitCargo(typeId: item.id, amount: item.amount)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }

                    if let target = state.nativeTradeTargetsForSelectedUnit.first {
                        Menu("Native Settlement: \(target.name)") {
                            Button("Trade…") {
                                state.openNativeTradeWithSelectedUnit(settlementId: target.settlementId)
                            }
                            .disabled(!state.canOpenNativeTrade)

                            Button("Deliver Gift") {
                                state.deliverGiftToSettlement(target.settlementId)
                            }
                            .disabled(!state.canDeliverGiftWithSelectedUnit)

                            Button("Demand Tribute") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.demandTributeFromSettlement(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canDemandTributeWithSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Spy") {
                                state.spyOnNativeSettlement(settlementId: target.settlementId)
                            }
                            .disabled(!state.canSpyOnNativeSettlement)

                            Button("Scout Settlement") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.scoutIndianSettlement(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canScoutIndianSettlement
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Ask Skill") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.askSkillAtSelectedUnit(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canAskSkillAtSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Learn Skill") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.learnSkillAtSelectedUnit(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canLearnSkillAtSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Menu("Incite…") {
                                ForEach(state.diplomacyVictimOptions(), id: \.id) { victim in
                                    Button(victim.label) {
                                        state.inciteSettlement(
                                            settlementId: target.settlementId,
                                            enemyPlayerId: victim.id,
                                            gold: 0)
                                    }
                                }
                            }
                            .disabled(!state.canInciteSelectedUnit)
                        }
                        .font(.caption)
                        .fixedSize()
                    }

                    if !state.diplomacyInitiationTargetsForSelectedUnit.isEmpty {
                        Menu("Diplomacy…") {
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
            .buttonStyle(.bordered)
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
        return (1600 + delta / 2, delta % 2 == 0 ? "Frühling" : "Herbst")
    }
}

private struct GameActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
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
