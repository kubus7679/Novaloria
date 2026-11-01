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
            Button("Warten") { state.setSelectedUnitState(.skipped) }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            Button("Überspringen") { state.setSelectedUnitState(.skipped) }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            Button("Wache") { state.setSelectedUnitState(.sentry) }
                .disabled(!state.canChangeSelectedUnitState(to: .sentry))
            Button("Befestigen") { state.setSelectedUnitState(.fortifying) }
                .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
            Divider()
            Button("Kolonie gründen") { state.buildColony(name: state.suggestedColonyName) }
                .disabled(!state.canBuildSelectedColony)
            if state.showsColonyWorkOrder {
                Button("In der Kolonie arbeiten") { state.joinSelectedColony() }
                    .disabled(!state.canJoinSelectedColony)
            }
            Menu("Verwalten") {
                Button("Einheit auflösen…", role: .destructive) { state.disbandSelectedUnit() }
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
            Button("Befehle löschen") { state.clearSelectedUnitOrders() }
                .disabled(!state.canClearSelectedUnitOrders)
            if state.showsEuropeTravelOrder {
                Button("Nach Europa") { state.sendSelectedUnitToEurope() }
                    .disabled(!state.canSendSelectedUnitToEurope)
            }
            Divider()
            Button("Nächste Einheit") { state.selectNextUnit() }
                .disabled(state.cyclingLocalUnits.isEmpty)
            Button("Vorherige Einheit") { state.selectPreviousUnit() }
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
}
