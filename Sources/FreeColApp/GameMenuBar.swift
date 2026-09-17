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
        Menu("Game") {
            Button("End Turn") { state.endTurn() }
                .disabled(!state.canEndTurn)
            Divider()
            Button("Chat…") { onChat() }
            Button("Declare Independence…") { onIndependence() }
                .disabled(!state.isLocalPlayersTurn)
            Button("Retire…") { state.retireGame() }
                .disabled(!state.isGameEnded && !state.isLocalPlayersTurn)
            Divider()
            Button("High Scores") {
                state.requestedReport = .highScores
                onReports()
            }
            Button("Preferences…") { onPreferences() }
            Divider()
            Button("Disconnect") { state.disconnect() }
        }
    }

    // MARK: - View

    private var viewMenu: some View {
        Menu("View") {
            Toggle("Map Grid", isOn: Binding(
                get: { state.showMapGrid },
                set: { _ in state.toggleMapGrid() }
            ))
            Toggle("Borders", isOn: Binding(
                get: { state.showBorders },
                set: { _ in state.toggleBorders() }
            ))
            Toggle("Fog of War", isOn: Binding(
                get: { state.showFogOfWar },
                set: { _ in state.toggleFogOfWar() }
            ))
            Divider()
            Button("Europe…") { state.openEuropePanel() }
                .disabled(state.localPlayer?.europe == nil)
            Button("Find Settlement…") { onFindSettlement() }
        }
    }

    // MARK: - Orders

    private var ordersMenu: some View {
        Menu("Orders") {
            Button("Wait") { state.setSelectedUnitState(.skipped) }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            Button("Skip") { state.setSelectedUnitState(.skipped) }
                .disabled(!state.canChangeSelectedUnitState(to: .skipped))
            Button("Sentry") { state.setSelectedUnitState(.sentry) }
                .disabled(!state.canChangeSelectedUnitState(to: .sentry))
            Button("Fortify") { state.setSelectedUnitState(.fortifying) }
                .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
            Divider()
            Button("Build Colony") { state.buildColony(name: "New Colony") }
                .disabled(!state.canBuildSelectedColony)
            Button("Join Colony") { state.joinSelectedColony() }
                .disabled(!state.canJoinSelectedColony)
            Button("Disband Unit") { state.disbandSelectedUnit() }
                .disabled(!state.canDisbandSelectedUnit)
            Divider()
            Button("Set Destination (Selected Tile)") {
                if let tileId = state.selectedTileId {
                    state.setSelectedUnitDestination(to: tileId)
                }
            }
            .disabled(!state.canSetDestinationToSelectedTile)
            Button("Clear Destination") { state.clearSelectedUnitDestination() }
                .disabled(!state.canClearSelectedUnitDestination)
            Divider()
            Button("Trade Routes…") { onTradeRoutes() }
                .disabled(!state.canManageTradeRoutes)
        }
    }

    // MARK: - Report

    private var reportMenu: some View {
        Menu("Report") {
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
        Menu("Colopedia") {
            Button("Open Colopedia…") { onColopedia() }
        }
    }
}
