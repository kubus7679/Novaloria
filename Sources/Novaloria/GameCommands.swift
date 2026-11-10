import SwiftUI
import FreeColGame

/// Native macOS menu-bar commands for in-game actions and views.
struct GameCommands: Commands {
    let state: GameState

    var body: some Commands {
        CommandMenu(L10n.text("Spiel", table: "GameCommands")) { gameMenu.disabled(state.phase != .inGame) }
        CommandGroup(after: .sidebar) {
            viewMenu.disabled(state.phase != .inGame)
        }
        CommandMenu(L10n.text("Befehle", table: "GameCommands")) { ordersMenu.disabled(state.phase != .inGame) }
        CommandMenu(L10n.text("Berichte", table: "GameCommands")) { reportMenu.disabled(state.phase != .inGame) }
        CommandMenu(L10n.text("Colopädie", table: "GameCommands")) { colopediaMenu.disabled(state.phase != .inGame) }
        CommandGroup(after: .help) {
            helpMenu.disabled(state.phase != .inGame)
        }
    }

    // MARK: - Game

    private var gameMenu: some View {
        Group {
            Button(state.isSavingGame
                   ? L10n.text("Wird gespeichert…", table: "GameCommands")
                   : L10n.text("Spiel speichern…", table: "GameCommands")) {
                state.showSaveGamePanel()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!state.canSaveGame)
            .help(L10n.text(
                "Vollständigen Spielstand speichern. Erfordert die Java-Speichererweiterung und Administratorrechte im eigenen Zug.",
                table: "GameCommands"
            ))
            Divider()
            Button(L10n.text("Zug beenden", table: "GameCommands")) { state.requestEndTurn() }
                .disabled(!state.canEndTurn)
            Divider()
            Button(L10n.text("Chat…", table: "GameCommands")) { state.showChatPanel = true }
            Button(L10n.text("Unabhängigkeit erklären…", table: "GameCommands")) { state.showIndependencePanel = true }
                .disabled(!state.isLocalPlayersTurn)
            Button(L10n.text("Aufgeben…", table: "GameCommands")) { state.retireGame() }
                .disabled(!state.isGameEnded && !state.isLocalPlayersTurn)
            Divider()
            Button(L10n.text("Bestenliste", table: "GameCommands")) {
                state.requestedReport = .highScores
                state.showReportsPanel = true
            }
            Button(L10n.text("Status…", table: "GameCommands")) { state.showStatusPanel = true }
            Button(L10n.text("Einstellungen…", table: "GameCommands")) { state.showPreferencesPanel = true }
            Divider()
            Button(L10n.text("Verbindung trennen", table: "GameCommands")) { state.disconnect() }
        }
    }

    // MARK: - View

    private var viewMenu: some View {
        Group {
            Button(L10n.text("Hineinzoomen", table: "GameCommands")) { state.zoomMap(in: true) }
                .disabled(!state.canZoomMapIn)
            Button(L10n.text("Herauszoomen", table: "GameCommands")) { state.zoomMap(in: false) }
                .disabled(!state.canZoomMapOut)
            Button(L10n.text("Zoom zurücksetzen", table: "GameCommands")) {
                state.resetMapZoom()
            }
            .disabled(state.mapZoomScale == 2.0)
            Divider()
            Menu(L10n.text("Kartenüberlagerung", table: "GameCommands")) {
                ForEach(GameState.MapOverlay.allCases) { overlay in
                    Button {
                        state.mapOverlay = overlay
                    } label: {
                        if state.mapOverlay == overlay {
                            Label(overlay.title, systemImage: "checkmark")
                        } else {
                            Text(overlay.title)
                        }
                    }
                }
            }
            Divider()
            Toggle(L10n.text("Kartenraster", table: "GameCommands"), isOn: Binding(
                get: { state.showMapGrid },
                set: { _ in state.toggleMapGrid() }
            ))
            Toggle(L10n.text("Grenzen", table: "GameCommands"), isOn: Binding(
                get: { state.showBorders },
                set: { _ in state.toggleBorders() }
            ))
            Toggle(L10n.text("Siedlungsnamen", table: "GameCommands"), isOn: Binding(
                get: { state.showSettlementLabels },
                set: { state.showSettlementLabels = $0 }
            ))
            Toggle(L10n.text("Nebel des Krieges", table: "GameCommands"), isOn: Binding(
                get: { state.showFogOfWar },
                set: { _ in state.toggleFogOfWar() }
            ))
            Divider()
            Button(L10n.text("Europa…", table: "GameCommands")) { state.openEuropePanel() }
                .disabled(state.localPlayer?.europe == nil)
            Button(L10n.text("Kolonie öffnen…", table: "GameCommands")) { state.openColonyPanel() }
                .disabled(state.selectedColony == nil)
            Button(L10n.text("Siedlung suchen…", table: "GameCommands")) { state.showFindSettlementPanel = true }
            Button(L10n.text("Auswahl zentrieren", table: "GameCommands")) {
                if let tileId = state.selectedUnitTileId ?? state.selectedTileId {
                    state.requestMapScroll(to: tileId)
                }
            }
            .disabled(state.selectedUnitTileId == nil && state.selectedTileId == nil)
        }
    }

    // MARK: - Orders

    private var ordersMenu: some View {
        Group {
            Button(L10n.text("Bewegen…", table: "GameCommands")) { state.beginChoosingMoveDestination() }
                .disabled(!state.canChooseMoveDestination)
            Divider()
            commandButton(
                L10n.text("Warten", table: "GameCommands"),
                shortcutDescription: "Warten / Überspringen"
            ) {
                state.setSelectedUnitState(.skipped)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            commandButton(L10n.text("Wache", table: "GameCommands"), shortcutDescription: "Wache halten") {
                state.setSelectedUnitState(.sentry)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .sentry))
            commandButton(L10n.text("Befestigen", table: "GameCommands"), shortcutDescription: "Befestigen") {
                state.setSelectedUnitState(.fortifying)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
            Divider()
            commandButton(L10n.text("Kolonie gründen", table: "GameCommands"), shortcutDescription: "Kolonie bauen") {
                state.buildColony(name: state.suggestedColonyName)
            }
                .disabled(!state.canBuildSelectedColony)
            if state.showsColonyWorkOrder {
                commandButton(
                    L10n.text("In der Kolonie arbeiten", table: "GameCommands"),
                    shortcutDescription: "In der Kolonie arbeiten"
                ) {
                    state.joinSelectedColony()
                }
                    .disabled(!state.canJoinSelectedColony)
            }
            if state.selectedUnit?.role == "model.role.pioneer" {
                Menu(L10n.text("Pionierarbeit", table: "GameCommands")) {
                    if state.selectedUnitImprovementCandidates.isEmpty {
                        Button(L10n.text("Keine passende Verbesserung verfügbar", table: "GameCommands")) {}
                            .disabled(true)
                    } else {
                        ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                            Button(L10n.text("\(candidate.label) bauen", table: "GameCommands")) {
                                state.changeSelectedUnitWorkImprovement(candidate.id)
                            }
                            .disabled(!state.canChangeSelectedUnitWorkImprovement)
                        }
                    }
                }
            }
            Menu(L10n.text("Verwalten", table: "GameCommands")) {
                commandButton(
                    L10n.text("Einheit auflösen…", table: "GameCommands"),
                    shortcutDescription: "Einheit auflösen",
                    role: .destructive
                ) {
                    state.disbandSelectedUnit()
                }
                    .disabled(!state.canDisbandSelectedUnit)
            }
            Divider()
            Button(L10n.text("Ausgewähltes Feld als Ziel", table: "GameCommands")) {
                if let tileId = state.selectedTileId {
                    state.setSelectedUnitDestination(to: tileId)
                }
            }
            .disabled(!state.canSetDestinationToSelectedTile)
            Button(L10n.text("Ziel löschen", table: "GameCommands")) { state.clearSelectedUnitDestination() }
                .disabled(!state.canClearSelectedUnitDestination)
            commandButton(
                L10n.text("Befehle löschen", table: "GameCommands"),
                shortcutDescription: "Befehle löschen"
            ) {
                state.clearSelectedUnitOrders()
            }
                .disabled(!state.canClearSelectedUnitOrders)
            if state.showsEuropeTravelOrder {
                Button(L10n.text("Gehe nach Europa", table: "GameCommands")) { state.goSelectedShipToEurope() }
                    .disabled(!state.canGoSelectedShipToEurope)
            }
            Divider()
            commandButton(
                L10n.text("Nächste Einheit", table: "GameCommands"),
                shortcutDescription: "Nächste Einheit auswählen"
            ) {
                state.selectNextUnit()
            }
                .disabled(state.cyclingLocalUnits.isEmpty)
            commandButton(
                L10n.text("Vorherige Einheit", table: "GameCommands"),
                shortcutDescription: "Vorherige Einheit auswählen"
            ) {
                state.selectPreviousUnit()
            }
                .disabled(state.cyclingLocalUnits.isEmpty)
            Button(L10n.text("Nächste Einheit ohne Befehl", table: "GameCommands")) {
                state.selectAdjacentUnit(forward: true, onlyAwaitingOrders: true)
            }
            .disabled(state.unitsAwaitingOrders.isEmpty)
            Divider()
            Button(L10n.text("Handelsrouten…", table: "GameCommands")) { state.showTradeRoutesPanel = true }
                .disabled(!state.canManageTradeRoutes)
        }
    }

    private func commandButton(
        _ title: String,
        shortcutDescription: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let shortcut = state.keyboardShortcutsManager?.shortcuts.first(
            where: { $0.description == shortcutDescription }
        )
        let label = shortcut.map { "\(title)    \($0.fullDisplay)" } ?? title
        return Button(label, role: role, action: action)
    }

    // MARK: - Report

    private var reportMenu: some View {
        Group {
            ForEach(ReportKind.allCases) { kind in
                Button(kind.title) {
                    state.requestedReport = kind
                    state.showReportsPanel = true
                }
            }
        }
    }

    // MARK: - Colopedia

    private var colopediaMenu: some View {
        Group {
            ForEach(ColopediaCategory.allCases, id: \.self) { category in
                Button(category.title) {
                    state.requestedColopediaCategory = category
                    state.showColopediaPanel = true
                }
            }
        }
    }

    // MARK: - Help

    private var helpMenu: some View {
        Button(L10n.text("Tastaturkürzel…", table: "GameCommands")) {
            state.showShortcutsHelp = true
        }
        .help(L10n.text("Zeigt alle verfügbaren Tastaturkürzel an", table: "GameCommands"))
    }
}
