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
                    Label("Alle Einheiten befohlen", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        state.selectAdjacentUnit(forward: true, onlyAwaitingOrders: true)
                    } label: {
                        Label("\(state.unitsAwaitingOrders.count) ohne Befehl",
                              systemImage: "arrow.right.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Wählt die nächste Einheit ohne Befehl aus und zentriert die Karte, falls sie sich dort befindet.")
                    .accessibilityLabel("\(state.unitsAwaitingOrders.count) Einheiten ohne Befehl. Nächste Einheit auswählen.")
                    .accessibilityIdentifier("units-awaiting-orders")
                }
                Button("Zugbericht (\(state.localPlayerModelMessages.count))") {
                    state.requestedReport = .turn
                    state.showReportsPanel = true
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
                                        Label(colony.name ?? "Kolonie", systemImage: "checkmark")
                                    } else {
                                        Text(colony.name ?? "Kolonie")
                                    }
                                }
                                .accessibilityIdentifier("select-colony-\(colony.id)")
                            }
                        } label: {
                            Text(selectedColony.name ?? "Kolonie")
                                .font(.title2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.tail)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .disabled(state.coloniesForNavigation.isEmpty)
                        .accessibilityLabel("Kolonie auswählen")
                        .accessibilityIdentifier("colony-selector")
                        Spacer()
                        Button {
                            state.selectPreviousColony()
                        } label: {
                            Label("Vorherige", systemImage: "chevron.left")
                        }
                        .disabled(!state.canNavigateColonies)
                        .accessibilityIdentifier("previous-colony")
                        Button {
                            state.selectNextColony()
                        } label: {
                            Label("Nächste", systemImage: "chevron.right")
                        }
                        .disabled(!state.canNavigateColonies)
                        .accessibilityIdentifier("next-colony")
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
                        carrierGoods: state.selectedColonyCarrierGoods,
                        buildTargetLabel: state.selectedColonyBuildTarget?.label,
                        buildRequirements: state.selectedColonyBuildRequirements,
                        buildETATurns: state.selectedColonyEstimatedBuildTurns,
                        estimatedBuildPerTurn: state.selectedColonyEstimatedBuildPerTurn,
                        estimatedProduction: state.selectedColonyEstimatedProduction
                    )
                    .id(selectedColony.id)
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
                    Text("Diagnose").font(.headline)
                    Spacer()
                    Button("Schließen") { state.closeDebugPanel() }
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
            "Angriff bestätigen",
            isPresented: Binding(
                get: { state.showAttackConfirmation },
                set: { if !$0 { state.dismissPendingAttack() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Angreifen", role: .destructive) { state.confirmPendingAttack() }
            Button("Abbrechen", role: .cancel) { state.dismissPendingAttack() }
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
                Button("Verbindung trennen") { state.disconnect() }
            }
        }
        } // End KeyboardShortcutHandlerView
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Aktion fehlgeschlagen", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                Spacer(minLength: 4)
                Button("Schließen") { state.clearError() }
                    .font(.caption)
                    .buttonStyle(.plain)
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityLabel("Fehler: \(message)")

            if let recoveryTitle = state.errorRecoveryActionTitle {
                Button(recoveryTitle) { state.performErrorRecoveryAction() }
                    .buttonStyle(.bordered)
                    .help("Behebt den bekannten Bewegungsfehler, sofern die Aktion weiterhin möglich ist.")
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
                Text("Ausstehende Aktionen – vor dem erneuten Senden prüfen")
                    .font(.caption.bold())
                ForEach(state.queuedGameplayActions) { action in
                    HStack {
                        Text(action.title)
                            .font(.caption)
                        Spacer()
                        Button("Erneut senden") {
                            queuedActionToConfirm = action
                            showQueuedActionConfirmation = true
                        }
                        .disabled(state.phase != .inGame)
                        Button("Verwerfen") {
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
            .alert("Aktion erneut senden?", isPresented: $showQueuedActionConfirmation) {
                Button("Erneut senden", role: .destructive) {
                    if let action = queuedActionToConfirm {
                        state.resendQueuedGameplayAction(action)
                    }
                    queuedActionToConfirm = nil
                }
                Button("Abbrechen", role: .cancel) {
                    queuedActionToConfirm = nil
                }
            } message: {
                Text("Der Server könnte diese Aktion bereits vor dem Verbindungsabbruch verarbeitet haben.")
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
                                Text("\(unit.displayMovesLeft) Bewegungspunkte")
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
            Text("Besiegt")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Deine Nation wurde ausgeschaltet.")
                .foregroundColor(.white)
            HStack(spacing: 12) {
                if !state.isUndead {
                    Button("Rachemodus starten") {
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
            Text("Sieg!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(state.gameEndedHighScore
                 ? "Du hast das Spiel mit einer Spitzenpunktzahl gewonnen."
                 : "Du hast das Spiel gewonnen!")
                .foregroundColor(.white)
            HStack(spacing: 12) {
                Button("Weiterspielen") {
                    state.continueAfterVictory()
                }
                .buttonStyle(.borderedProminent)
                Button("Aufgeben") {
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
            if let game = state.game {
                let turnInfo = yearSeason(for: game.turn.number)
                let date = turnInfo.season.map { "\($0) \(turnInfo.year)" } ?? "Jahr \(turnInfo.year)"
                Text("R\(game.turn.number) · \(turnInfo.year)")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .help("Runde \(game.turn.number), \(date)")
                    .accessibilityLabel("Runde \(game.turn.number), \(date)")
                if let local = state.localPlayer {
                    resourceItem("\(local.gold)", systemImage: "dollarsign.circle.fill", help: "Gold")
                }
            }
            Spacer(minLength: 4)
            if !state.statusMessage.isEmpty, state.pendingServerDecision == nil {
                Text(state.statusMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            Button("Zug beenden") { state.requestEndTurn() }
                .buttonStyle(GameActionButtonStyle())
                .disabled(!state.canEndTurn)
                .help("Vor dem Zugende werden Einheiten ohne Befehl angezeigt.")
            Menu {
                Button("Nächste Einheit") { state.selectNextUnit() }
                    .disabled(state.cyclingLocalUnits.isEmpty)
                Divider()
                if let local = state.localPlayer {
                    Section("Weitere Werte") {
                        Text("Steuern: \(local.tax)%")
                        Text("Freiheit: \(local.liberty)")
                        if let required = local.immigrationRequired {
                            Text("Einwanderung: \(local.immigration)/\(required)")
                        }
                        Text("Punkte: \(local.score)")
                    }
                }
                Button("Berichte…") {
                    state.requestedReport = .turn
                    state.showReportsPanel = true
                }
                Button("Status…") { state.showStatusPanel = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Weitere Spielwerte und Aktionen")
            .accessibilityLabel("Weitere Spielwerte und Aktionen")
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
        .accessibilityLabel("\(help): \(value)")
    }

    private func shortcutLabel(_ title: String, description: String) -> String {
        guard let shortcut = state.keyboardShortcutsManager?.shortcuts.first(
            where: { $0.description == description }
        ) else { return title }
        return "\(title) (\(shortcut.fullDisplay))"
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
            Text("Keine Fracht verfügbar.")
                .font(.caption2)
                .foregroundColor(.secondary)
            Button("Nichts nehmen") { state.lootPendingCargo(selected: []) }
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
                    Text("\(state.goodsDisplayName(option.type)) ×\(option.amount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .toggleStyle(.checkbox)
            }
            HStack(spacing: 8) {
                Button("Ausgewählte nehmen") {
                    state.lootPendingCargo(selected: options.filter { selectedLootTypes.contains($0.type) })
                    selectedLootTypes.removeAll()
                }
                .buttonStyle(.borderedProminent)
                Button("Nichts nehmen") {
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
            Text("Keine Auswanderer verfügbar.")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            ForEach(options) { option in
                Button {
                    state.emigratePendingMigrant(slot: option.slot)
                } label: {
                    Text("\(option.unitType.map(state.unitDisplayName) ?? "Einheit") platzieren")
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
                Button("Bestätigen") {
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
            Text("Unabhängigkeit erklären")
                .font(.title3.bold())
            HStack {
                Text("Land:")
                    .frame(width: 70, alignment: .trailing)
                TextField("Land", text: $independenceCountry)
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
                Button("Abbrechen") { state.showIndependencePanel = false }
                Button("Erklären") {
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
                Button("Schließen") { state.showFindSettlementPanel = false }
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
                        .buttonStyle(.borderedProminent)
                        .help(state.selectedUnitMoveDisabledReason
                              ?? "Wählt ein Zielfeld per Linksklick. Alternativ bewegt ein Rechtsklick auf ein Feld die Einheit direkt.")
                        .disabled(!state.canChooseMoveDestination)

                    if let tileId = state.selectedTileId,
                        state.canMoveSelectedUnitTo(destinationTileId: tileId)
                    {
                        Button("Zum ausgewählten Feld") {
                            state.moveSelectedUnitTo(destinationTileId: tileId)
                        }
                    }

                    if state.selectedColony != nil {
                        Button(shortcutLabel("Kolonie öffnen", description: "Kolonie-Panel öffnen")) {
                            state.openColonyPanel()
                        }
                    }

                    actionSectionTitle("Einheitenbefehle")
                    Button(shortcutLabel("Aktivieren", description: "Einheit aktivieren")) {
                        state.setSelectedUnitState(.active)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .active))
                    .help(state.canChangeSelectedUnitState(to: .active)
                          ? "Einheit wieder für Befehle aktivieren."
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel("Warten", description: "Warten / Überspringen")) {
                        state.setSelectedUnitState(.skipped)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                    .help(state.canChangeSelectedUnitState(to: .skipped)
                          ? "Einheit bis zu einem späteren Zug überspringen."
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel("Wache", description: "Wache halten")) {
                        state.setSelectedUnitState(.sentry)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                    .help(state.canChangeSelectedUnitState(to: .sentry)
                          ? "Einheit in Verteidigungsbereitschaft versetzen."
                          : state.selectedUnitActionUnavailableReason)

                    Button(shortcutLabel("Befestigen", description: "Befestigen")) {
                        state.setSelectedUnitState(.fortifying)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                    .help(state.canChangeSelectedUnitState(to: .fortifying)
                          ? "Einheit befestigen."
                          : state.selectedUnitActionUnavailableReason)

                    if !state.selectedUnitImprovementCandidates.isEmpty {
                        actionSectionTitle("Pionierarbeit")
                        ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                            Button("\(candidate.label) bauen") {
                                state.changeSelectedUnitWorkImprovement(candidate.id)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canChangeSelectedUnitWorkImprovement)
                        }
                    }

                    Button(shortcutLabel("Befehle löschen", description: "Befehle löschen")) {
                        state.clearSelectedUnitOrders()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canClearSelectedUnitOrders)
                    .help(state.canClearSelectedUnitOrders
                          ? "Marschziel und Einheitenstatus zurücksetzen."
                          : state.selectedUnitActionUnavailableReason)

                    if state.showsEuropeTravelOrder {
                        Button("Gehe nach Europa") { state.goSelectedShipToEurope() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canGoSelectedShipToEurope)
                    }

                    Button("Einheit auflösen…", role: .destructive) {
                        state.disbandSelectedUnit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canDisbandSelectedUnit)
                    .help(state.selectedUnitDisbandDisabledReason
                          ?? "Einheit dauerhaft aus dem Spiel entfernen.")

                    if state.canBuildSelectedColony {
                        actionSectionTitle("Kolonie")
                        TextField("Koloniename", text: $colonyName)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { colonyName = state.suggestedColonyName }
                            .onChange(of: state.selectedUnitId) { _, _ in
                                colonyName = state.suggestedColonyName
                            }
                        Button(shortcutLabel("Kolonie gründen", description: "Kolonie bauen")) {
                            state.buildColony(name: colonyName)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(colonyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if state.canJoinSelectedColony {
                        actionSectionTitle("Kolonie")
                        Button(shortcutLabel("In der Kolonie arbeiten", description: "In der Kolonie arbeiten")) {
                            state.joinSelectedColony()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.embarkCarrierOptions.isEmpty {
                        actionSectionTitle("Transport")
                        ForEach(state.embarkCarrierOptions, id: \.id) { carrier in
                            Button(shortcutLabel("An Bord: \(carrier.unitType.map(state.unitDisplayName) ?? "Transporter")",
                                                description: "An Bord gehen")) {
                                state.embarkSelectedUnit(onCarrier: carrier.id)
                            }
                            .disabled(!state.canEmbarkSelectedUnit(onCarrier: carrier.id))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if state.selectedUnitCarrier != nil {
                        actionSectionTitle("Transport")
                        Button(shortcutLabel("Von Bord gehen", description: "Von Bord gehen")) {
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
                        actionSectionTitle("Angriff")
                        Button(shortcutLabel("Nahkampf", description: "Nahkampf")) {
                            state.requestAttack(onTile: targetTileId, ranged: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitMelee(onTile: targetTileId))
                        .help(state.canAttackSelectedUnitMelee(onTile: targetTileId)
                              ? "Das ausgewählte Feld im Nahkampf angreifen."
                              : state.selectedUnitActionUnavailableReason)

                        Button(shortcutLabel("Fernkampf", description: "Fernkampf")) {
                            state.requestAttack(onTile: targetTileId, ranged: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(!state.canAttackSelectedUnitRanged(onTile: targetTileId))
                        .help(state.canAttackSelectedUnitRanged(onTile: targetTileId)
                              ? "Das ausgewählte Feld im Fernkampf angreifen."
                              : state.selectedUnitActionUnavailableReason)
                    }

                    actionSectionTitle("Marschziel")
                    Button("Ausgewähltes Feld als Ziel") {
                        if let tileId = state.selectedTileId {
                            state.setSelectedUnitDestination(to: tileId)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canSetDestinationToSelectedTile)
                    .help(state.canSetDestinationToSelectedTile
                          ? "Das ausgewählte Kartenfeld als Marschziel festlegen."
                          : state.selectedUnitActionUnavailableReason)

                    Button("Ziel löschen") {
                        state.clearSelectedUnitDestination()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!state.canClearSelectedUnitDestination)
                    .help(state.canClearSelectedUnitDestination
                          ? "Das gespeicherte Marschziel entfernen."
                          : state.selectedUnitActionUnavailableReason)

                    if state.canEquipSelectedUnitForRole {
                        actionSectionTitle("Ausrüstung")
                        Button("Als Missionar ausrüsten") {
                            state.equipSelectedUnitForRole("model.role.missionary", count: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if state.canEquipSelectedUnitAsPioneer {
                        if !state.canEquipSelectedUnitForRole { actionSectionTitle("Ausrüstung") }
                        Button(state.selectedUnit?.role == "model.role.pioneer"
                               ? "Pionier-Werkzeuge nachrüsten (+\(state.pioneerToolsPerRoleCount))"
                               : "Als Pionier ausrüsten (\(state.pioneerToolsPerRoleCount) Werkzeuge)") {
                            state.equipSelectedUnitForRole(
                                "model.role.pioneer",
                                count: state.selectedUnitPioneerEquipmentCount
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.selectedUnitCargoUnits.isEmpty {
                        actionSectionTitle("Passagiere")
                        ForEach(state.selectedUnitCargoUnits, id: \.id) { cargo in
                            Button("Auswählen: \(cargo.unitType.map(state.unitDisplayName) ?? "Einheit")") {
                                let tileId = state.selectedUnitTileId
                                state.selectUnit(
                                    cargo.id,
                                    onTile: tileId.flatMap { state.game?.tiles[$0] != nil ? $0 : nil })
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !state.selectedUnitCargoGoods.isEmpty {
                        actionSectionTitle("Ladung")
                        ForEach(state.selectedUnitCargoGoods, id: \.id) { item in
                            HStack {
                                Text("\(item.label): \(item.amount)")
                                Spacer()
                                Button(role: .destructive) {
                                    state.dumpSelectedUnitCargo(typeId: item.id, amount: item.amount)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .help("\(item.label) abwerfen")
                                .accessibilityLabel("\(item.label) abwerfen")
                            }
                        }
                    }

                    if let target = state.nativeTradeTargetsForSelectedUnit.first {
                        actionSectionTitle("Ureinwohner-Siedlung")
                        Menu("\(target.name)") {
                            Button("Handeln…") {
                                state.openNativeTradeWithSelectedUnit(settlementId: target.settlementId)
                            }
                            .disabled(!state.canOpenNativeTrade)

                            Button("Geschenk überbringen") {
                                state.deliverGiftToSettlement(target.settlementId)
                            }
                            .disabled(!state.canDeliverGiftWithSelectedUnit)

                            Button("Tribut fordern") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.demandTributeFromSettlement(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canDemandTributeWithSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Ausspionieren") {
                                state.spyOnNativeSettlement(settlementId: target.settlementId)
                            }
                            .disabled(!state.canSpyOnNativeSettlement)

                            Button("Siedlung erkunden") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.scoutIndianSettlement(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canScoutIndianSettlement
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Fähigkeit erfragen") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.askSkillAtSelectedUnit(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canAskSkillAtSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Button("Fähigkeit erlernen") {
                                if let direction = state.directionToAdjacentSettlement(target.settlementId) {
                                    state.learnSkillAtSelectedUnit(direction: direction)
                                }
                            }
                            .disabled(
                                !state.canLearnSkillAtSelectedUnit
                                    || state.directionToAdjacentSettlement(target.settlementId) == nil)

                            Menu("Aufstand anzetteln…") {
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
                        Menu(state.diplomacyContextForSelectedUnit == "TRIBUTE" ? "Tribut verhandeln…" : "Diplomatie…") {
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
        return (1600 + delta / 2, delta % 2 == 0 ? "Frühling" : "Herbst")
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
