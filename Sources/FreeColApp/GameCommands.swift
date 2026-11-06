import SwiftUI
import FreeColGame

/// Native macOS menu-bar commands for in-game actions and views.
struct GameCommands: Commands {
    let state: GameState

    var body: some Commands {
        CommandMenu("Spiel") { gameMenu.disabled(state.phase != .inGame) }
        CommandGroup(after: .sidebar) {
            viewMenu.disabled(state.phase != .inGame)
        }
        CommandMenu("Befehle") { ordersMenu.disabled(state.phase != .inGame) }
        CommandMenu("Berichte") { reportMenu.disabled(state.phase != .inGame) }
        CommandMenu("Colopädie") { colopediaMenu.disabled(state.phase != .inGame) }
        CommandGroup(after: .help) {
            helpMenu.disabled(state.phase != .inGame)
        }
    }

    // MARK: - Game

    private var gameMenu: some View {
        Group {
            Button(state.isSavingGame ? "Wird gespeichert…" : "Spiel speichern…") {
                state.showSaveGamePanel()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!state.canSaveGame)
            .help("Vollständigen Spielstand speichern. Erfordert die Java-Speichererweiterung und Administratorrechte im eigenen Zug.")
            Divider()
            Button("Zug beenden") { state.requestEndTurn() }
                .disabled(!state.canEndTurn)
            Divider()
            Button("Chat…") { state.showChatPanel = true }
            Button("Unabhängigkeit erklären…") { state.showIndependencePanel = true }
                .disabled(!state.isLocalPlayersTurn)
            Button("Aufgeben…") { state.retireGame() }
                .disabled(!state.isGameEnded && !state.isLocalPlayersTurn)
            Divider()
            Button("Bestenliste") {
                state.requestedReport = .highScores
                state.showReportsPanel = true
            }
            Button("Status…") { state.showStatusPanel = true }
            Button("Einstellungen…") { state.showPreferencesPanel = true }
            Divider()
            Button("Verbindung trennen") { state.disconnect() }
        }
    }

    // MARK: - View

    private var viewMenu: some View {
        Group {
            Button("Hineinzoomen") { state.zoomMap(in: true) }
                .disabled(!state.canZoomMapIn)
            Button("Herauszoomen") { state.zoomMap(in: false) }
                .disabled(!state.canZoomMapOut)
            Button("Zoom zurücksetzen") {
                state.resetMapZoom()
            }
            .disabled(state.mapZoomScale == 2.0)
            Divider()
            Menu("Kartenüberlagerung") {
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
            Toggle("Kartenraster", isOn: Binding(
                get: { state.showMapGrid },
                set: { _ in state.toggleMapGrid() }
            ))
            Toggle("Grenzen", isOn: Binding(
                get: { state.showBorders },
                set: { _ in state.toggleBorders() }
            ))
            Toggle("Siedlungsnamen", isOn: Binding(
                get: { state.showSettlementLabels },
                set: { state.showSettlementLabels = $0 }
            ))
            Toggle("Nebel des Krieges", isOn: Binding(
                get: { state.showFogOfWar },
                set: { _ in state.toggleFogOfWar() }
            ))
            Divider()
            Button("Europa…") { state.openEuropePanel() }
                .disabled(state.localPlayer?.europe == nil)
            Button("Kolonie öffnen…") { state.openColonyPanel() }
                .disabled(state.selectedColony == nil)
            Button("Siedlung suchen…") { state.showFindSettlementPanel = true }
            Button("Auswahl zentrieren") {
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
            Button("Bewegen…") { state.beginChoosingMoveDestination() }
                .disabled(!state.canChooseMoveDestination)
            Divider()
            commandButton("Warten", shortcutDescription: "Warten / Überspringen") {
                state.setSelectedUnitState(.skipped)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            commandButton("Wache", shortcutDescription: "Wache halten") {
                state.setSelectedUnitState(.sentry)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .sentry))
            commandButton("Befestigen", shortcutDescription: "Befestigen") {
                state.setSelectedUnitState(.fortifying)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
            Divider()
            commandButton("Kolonie gründen", shortcutDescription: "Kolonie bauen") {
                state.buildColony(name: state.suggestedColonyName)
            }
                .disabled(!state.canBuildSelectedColony)
            if state.showsColonyWorkOrder {
                commandButton("In der Kolonie arbeiten", shortcutDescription: "In der Kolonie arbeiten") {
                    state.joinSelectedColony()
                }
                    .disabled(!state.canJoinSelectedColony)
            }
            if state.selectedUnit?.role == "model.role.pioneer" {
                Menu("Pionierarbeit") {
                    if state.selectedUnitImprovementCandidates.isEmpty {
                        Button("Keine passende Verbesserung verfügbar") {}
                            .disabled(true)
                    } else {
                        ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                            Button("\(candidate.label) bauen") {
                                state.changeSelectedUnitWorkImprovement(candidate.id)
                            }
                            .disabled(!state.canChangeSelectedUnitWorkImprovement)
                        }
                    }
                }
            }
            Menu("Verwalten") {
                commandButton(
                    "Einheit auflösen…",
                    shortcutDescription: "Einheit auflösen",
                    role: .destructive
                ) {
                    state.disbandSelectedUnit()
                }
                    .disabled(!state.canDisbandSelectedUnit)
            }
            Divider()
            Button("Ausgewähltes Feld als Ziel") {
                if let tileId = state.selectedTileId {
                    state.setSelectedUnitDestination(to: tileId)
                }
            }
            .disabled(!state.canSetDestinationToSelectedTile)
            Button("Ziel löschen") { state.clearSelectedUnitDestination() }
                .disabled(!state.canClearSelectedUnitDestination)
            commandButton("Befehle löschen", shortcutDescription: "Befehle löschen") {
                state.clearSelectedUnitOrders()
            }
                .disabled(!state.canClearSelectedUnitOrders)
            if state.showsEuropeTravelOrder {
                Button("Gehe nach Europa") { state.goSelectedShipToEurope() }
                    .disabled(!state.canGoSelectedShipToEurope)
            }
            Divider()
            commandButton("Nächste Einheit", shortcutDescription: "Nächste Einheit auswählen") {
                state.selectNextUnit()
            }
                .disabled(state.cyclingLocalUnits.isEmpty)
            commandButton("Vorherige Einheit", shortcutDescription: "Vorherige Einheit auswählen") {
                state.selectPreviousUnit()
            }
                .disabled(state.cyclingLocalUnits.isEmpty)
            Button("Nächste Einheit ohne Befehl") {
                state.selectAdjacentUnit(forward: true, onlyAwaitingOrders: true)
            }
            .disabled(state.unitsAwaitingOrders.isEmpty)
            Divider()
            Button("Handelsrouten…") { state.showTradeRoutesPanel = true }
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
            Button("Colopädie öffnen…") { state.showColopediaPanel = true }
        }
    }

    // MARK: - Help

    private var helpMenu: some View {
        Button("Tastaturkürzel…") {
            state.showShortcutsHelp = true
        }
        .help("Zeigt alle verfügbaren Tastaturkürzel an")
    }
}
