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
                Button("Kolonie öffnen") { state.openColonyPanel() }
                Divider()
            }

            if state.selectedUnitId != nil {
                Button("Hierher bewegen") {
                    state.moveSelectedUnitTo(destinationTileId: tileId)
                    state.closeTileActions()
                }
                    .disabled(!state.canMoveSelectedUnitTo(destinationTileId: tileId))
                Button("Als Ziel setzen") { state.setSelectedUnitDestination(to: tileId) }
                    .disabled(!state.canSetSelectedUnitDestination(to: tileId))
                Button("Befehle löschen") { state.clearSelectedUnitOrders() }
                    .disabled(!state.canClearSelectedUnitOrders)
                Divider()
                Button("Befestigen") { state.setSelectedUnitState(.fortifying) }
                    .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                Button("Wache") { state.setSelectedUnitState(.sentry) }
                    .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                Button("Warten") { state.setSelectedUnitState(.skipped) }
                    .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                if state.showsEuropeTravelOrder {
                    Button("Gehe nach Europa") { state.goSelectedShipToEurope() }
                        .disabled(!state.canGoSelectedShipToEurope)
                }
                if state.canChangeSelectedUnitWorkImprovement {
                    Divider()
                    improvementPicker
                }
                Divider()
            }

            Button("Kolonie gründen") {
                state.selectUnit(state.selectedUnitId, onTile: tileId)
                state.buildColony(name: state.suggestedColonyName)
            }
            .disabled(!canBuildColonyHere)

            Button("Feld auswählen") {
                state.selectUnit(nil, onTile: tileId)
                state.closeTileActions()
            }

            Divider()

            Button("Schließen") { state.closeTileActions() }
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
            Text(state.tileActionTile.map { "Feld (\($0.x), \($0.y))" } ?? "Feld")
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
            Picker("Verbesserung", selection: $improvementTypeId) {
                ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                    Text(GameLabels.name(candidate.id)).tag(candidate.id)
                }
            }
            .labelsHidden()
            let toolCost = state.selectedUnitImprovementToolCost(for: improvementTypeId)
            if toolCost > 0 {
                Text("Verbrauch bei Fertigstellung: \(toolCost) Werkzeuge")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button("Verbesserung bauen") {
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
        return "\(type) · \(unit.displayMovesLeft) Bewegungspunkte"
    }

    private func shortName(_ value: String) -> String {
        GameLabels.name(value)
    }
}
