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

            if state.selectedUnitId != nil {
                Button("Move Here") { state.moveSelectedUnitTo(destinationTileId: tileId) }
                    .disabled(!state.canMoveSelectedUnitTo(destinationTileId: tileId))
                Button("Set Destination") { state.setSelectedUnitDestination(to: tileId) }
                    .disabled(!state.canSetSelectedUnitDestination(to: tileId))
                Button("Clear Orders") { state.clearSelectedUnitOrders() }
                    .disabled(!state.canClearSelectedUnitOrders)
                Divider()
                Button("Fortify") { state.setSelectedUnitState(.fortifying) }
                    .disabled(!state.canChangeSelectedUnitState(to: .fortifying))
                Button("Sentry") { state.setSelectedUnitState(.sentry) }
                    .disabled(!state.canChangeSelectedUnitState(to: .sentry))
                Button("Skip") { state.setSelectedUnitState(.skipped) }
                    .disabled(!state.canChangeSelectedUnitState(to: .skipped))
                if state.canSendSelectedUnitToEurope {
                    Button("Go To Europe") { state.sendSelectedUnitToEurope() }
                }
                if state.canChangeSelectedUnitWorkImprovement {
                    Divider()
                    improvementPicker
                }
                Divider()
            }

            Button("Build Colony") {
                state.selectUnit(state.selectedUnitId, onTile: tileId)
                state.buildColony(name: "New Colony")
            }
            .disabled(!canBuildColonyHere)

            Button("Select Tile") {
                state.selectUnit(nil, onTile: tileId)
                state.closeTileActions()
            }

            Divider()

            Button("Close") { state.closeTileActions() }
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
            Text("Tile \(tileId)")
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
            Text("Pioneer Improvement")
                .font(.caption2)
                .foregroundColor(.secondary)
            Picker("Improvement", selection: $improvementTypeId) {
                ForEach(state.selectedUnitImprovementCandidates, id: \.id) { candidate in
                    Text(candidate.label).tag(candidate.id)
                }
            }
            .labelsHidden()
            Button("Build Improvement") {
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
        return "\(type) · MP \(unit.movesLeft)"
    }

    private func shortName(_ value: String) -> String {
        value.split(separator: ".").last.map(String.init) ?? value
    }
}
