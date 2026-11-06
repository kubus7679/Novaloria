import SwiftUI
import FreeColGame

/// In-game menu bar mirroring the Java client's `InGameMenuBar`
/// (Game / View / Orders / Report / Colopedia).
struct GameMenuBar: View {
    @Environment(GameState.self) private var state

    var onChat: () -> Void
    var onReports: () -> Void
    var onPreferences: () -> Void
    var onColopedia: () -> Void
    var onIndependence: () -> Void
    var onFindSettlement: () -> Void
    var onTradeRoutes: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            gameMenu
            viewMenu
            ordersMenu
            reportMenu
            colopediaMenu
            helpMenu
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.caption)
    }

    // MARK: - Game

    private var gameMenu: some View {
        Menu("Spiel") {
            Button(state.isSavingGame ? "Wird gespeichert…" : "Spiel speichern…") {
                state.showSaveGamePanel()
            }
            .disabled(!state.canSaveGame)
            .help("Vollständigen Spielstand speichern. Erfordert die Java-Speichererweiterung und Administratorrechte im eigenen Zug.")
            Divider()
            Button("Zug beenden") { state.requestEndTurn() }
                .disabled(!state.canEndTurn)
            Divider()
            Button("Chat…") { onChat() }
            Button("Unabhängigkeit erklären…") { onIndependence() }
                .disabled(!state.isLocalPlayersTurn)
            Button("Aufgeben…") { state.retireGame() }
                .disabled(!state.isGameEnded && !state.isLocalPlayersTurn)
            Divider()
            Button("Bestenliste") {
                state.requestedReport = .highScores
                onReports()
            }
            Button("Status…") { state.showStatusPanel = true }
            Button("Einstellungen…") { onPreferences() }
            Divider()
            Button("Verbindung trennen") { state.disconnect() }
        }
    }

    // MARK: - View

    private var viewMenu: some View {
        Menu("Ansicht") {
            Toggle("Kartenraster", isOn: Binding(
                get: { state.showMapGrid },
                set: { _ in state.toggleMapGrid() }
            ))
            Toggle("Grenzen", isOn: Binding(
                get: { state.showBorders },
                set: { _ in state.toggleBorders() }
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
            Button("Siedlung suchen…") { onFindSettlement() }
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
        Menu("Befehle") {
            Button("Bewegen…") { state.beginChoosingMoveDestination() }
                .disabled(!state.canChooseMoveDestination)
            Divider()
            commandButton("Warten", shortcutDescription: "Warten / Überspringen") {
                state.setSelectedUnitState(.skipped)
            }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            commandButton("Überspringen", shortcutDescription: "Warten / Überspringen") {
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
            Button("Handelsrouten…") { onTradeRoutes() }
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
        Menu("Berichte") {
            ForEach(ReportKind.allCases) { kind in
                Button(kind.title) {
                    state.requestedReport = kind
                    onReports()
                }
            }
        }
    }

    // MARK: - Colopedia

    private var colopediaMenu: some View {
        Menu("Colopädie") {
            Button("Colopädie öffnen…") { onColopedia() }
        }
    }

    // MARK: - Help

    private var helpMenu: some View {
        Menu("Hilfe") {
            Button("Tastaturkürzel…") {
                state.showShortcutsHelp = true
            }
            .help("Zeigt alle verfügbaren Tastaturkürzel an")
        }
    }
}
