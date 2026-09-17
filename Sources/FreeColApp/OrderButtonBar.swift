import SwiftUI
import FreeColGame

/// Bottom-center unit order button bar, modelled on the Java client's unit action buttons.
struct OrderButtonBar: View {
    @Environment(GameState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            orderButton(name: "Wait", imageName: "wait", symbol: "pause.circle", action: {
                state.setSelectedUnitState(.skipped)
            }, enabled: state.canChangeSelectedUnitState(to: .skipped))

            orderButton(name: "Skip", imageName: nil, symbol: "forward.end.circle", action: {
                state.setSelectedUnitState(.skipped)
            }, enabled: state.canChangeSelectedUnitState(to: .skipped))

            orderButton(name: "Sentry", imageName: "sentry", symbol: "eye.circle", action: {
                state.setSelectedUnitState(.sentry)
            }, enabled: state.canChangeSelectedUnitState(to: .sentry))

            orderButton(name: "Fortify", imageName: "fortify", symbol: "shield.circle", action: {
                state.setSelectedUnitState(.fortifying)
            }, enabled: state.canChangeSelectedUnitState(to: .fortifying))

            orderButton(name: "Build Colony", imageName: "build", symbol: "hammer.circle", action: {
                if let game = state.game,
                   let unit = state.selectedUnit,
                   let loc = unit.location,
                   !game.tiles.isEmpty {
                    state.selectedTileId = loc
                }
                state.buildColony(name: "New Colony")
            }, enabled: state.canBuildSelectedColony)

            orderButton(name: "Disband", imageName: "disband", symbol: "trash.circle", action: {
                state.disbandSelectedUnit()
            }, enabled: state.canDisbandSelectedUnit)

            Divider()
                .frame(height: 26)

            orderButton(name: "End Turn", imageName: "done", symbol: "checkmark.circle", action: {
                state.endTurn()
            }, enabled: state.canEndTurn,
               highlighted: state.canEndTurn && !state.hasUnmovedLocalUnits)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func orderButton(name: String,
                             imageName: String?,
                             symbol: String,
                             action: @escaping () -> Void,
                             enabled: Bool,
                             highlighted: Bool = false) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let imageName,
                   let nsImg = TileImageCache.shared.orderButtonImage(named: imageName) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 26, height: 26)
                        .grayscale(enabled ? 0 : 1)
                        .opacity(enabled ? 1 : 0.4)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                        .frame(width: 26, height: 26)
                        .help(name)
                }
                Text(name)
                    .font(.system(size: 9))
                    .foregroundColor(enabled ? .white : .gray)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(highlighted ? Color.green.opacity(0.35) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(highlighted ? Color.green : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(name)
    }
}