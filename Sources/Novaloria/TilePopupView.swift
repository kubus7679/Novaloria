import SwiftUI
import FreeColGame

/// Context menu for a map tile, modelled on the Java client's `TilePopup`.
/// Presented when the map is right-clicked.
struct TilePopupView: View {
    @Environment(GameState.self) private var state
    let tileId: String

    @State private var improvementTypeId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let unit = state.selectedUnit {
                Text(unitTitle(unit))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            if state.selectedColony != nil {
                Button(L10n.text("Kolonie öffnen", table: "TilePopupView")) { state.openColonyPanel() }
                Divider()
            }

            if state.selectedUnitId != nil {
                Button(L10n.text("Hierher bewegen", table: "TilePopupView")) {
                    state.moveSelectedUnitTo(destinationTileId: tileId)
                    state.closeTileActions()
                }
                    .disabled(!state.canMoveSelectedUnitTo(destinationTileId: tileId))
                Button(L10n.text("Als Ziel setzen", table: "TilePopupView")) { state.setSelectedUnitDestination(to: tileId) }
                    .disabled(!state.canSetSelectedUnitDestination(to: tileId))
                Button(L10n.text("Befehle löschen", table: "TilePopupView")) { state.clearSelectedUnitOrders() }
                    .disabled(!state.canClearSelectedUnitOrders)
                Divider()
                Button(L10n.text("Befestigen", table: "TilePopupView")) { state.setSelectedUnitState(.fortifying) }
                    .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                Button(L10n.text("Wache", table: "TilePopupView")) { state.setSelectedUnitState(.sentry) }
                    .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                Button(L10n.text("Warten", table: "TilePopupView")) { state.setSelectedUnitState(.skipped) }
                    .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                if state.showsEuropeTravelOrder {
                    Button(L10n.text("Gehe nach Europa", table: "TilePopupView")) { state.goSelectedShipToEurope() }
                        .disabled(!state.canGoSelectedShipToEurope)
                }
                if state.canChangeSelectedUnitWorkImprovement {
                    Divider()
                    improvementPicker
                }
                Divider()
            }

            Button(L10n.text("Kolonie gründen", table: "TilePopupView")) {
                state.selectUnit(state.selectedUnitId, onTile: tileId)
                state.buildColony(name: state.suggestedColonyName)
            }
            .disabled(!canBuildColonyHere)

            Button(L10n.text("Feld auswählen", table: "TilePopupView")) {
                state.selectUnit(nil, onTile: tileId)
                state.closeTileActions()
            }

            Divider()

            Button(L10n.text("Schließen", table: "TilePopupView")) { state.closeTileActions() }
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.plain)
        .font(.caption)
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            if improvementTypeId.isEmpty, let first = state.selectedUnitImprovementCandidates.first {
                improvementTypeId = first.id
            }
        }
    }

    private var header: some View {
        HStack {
            Text(state.tileActionTile.map { L10n.text("Feld (\($0.x), \($0.y))", table: "TilePopupView") }
                ?? L10n.text("Feld", table: "TilePopupView"))
                .font(.caption.bold())
            Spacer()
            if let type = state.tileActionTile?.type {
                Text(shortName(type))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var improvementPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pionierarbeit")
                .font(.caption2)
                .foregroundColor(.secondary)
            Picker(L10n.text("Verbesserung", table: "TilePopupView"), selection: $improvementTypeId) {
                ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                    Text(GameLabels.name(candidate.id)).tag(candidate.id)
                }
            }
            .labelsHidden()
            let toolCost = state.selectedUnitImprovementToolCost(for: improvementTypeId)
            if toolCost > 0 {
                Text(L10n.text("Verbrauch bei Fertigstellung: \(toolCost) Werkzeuge", table: "TilePopupView"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button(L10n.text("Verbesserung bauen", table: "TilePopupView")) {
                state.changeSelectedUnitWorkImprovement(improvementTypeId)
            }
            .disabled(improvementTypeId.isEmpty)
        }
    }

    private var canBuildColonyHere: Bool {
        state.canBuildSelectedColony && state.selectedUnit?.location == tileId
    }

    private func unitTitle(_ unit: FreeColGame.Unit) -> String {
        let type = unit.unitType.map(shortName) ?? unit.id
        return L10n.text("\(type) · \(unit.displayMovesLeft) Bewegungspunkte", table: "TilePopupView")
    }

    private func shortName(_ value: String) -> String {
        GameLabels.name(value)
    }
}
