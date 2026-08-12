import SwiftUI
import FreeColGame

/// Bottom-right unit/tile/end-of-turn info panel, modelled on the Java client's InfoPanel.
struct InfoPanelView: View {
    @Environment(GameState.self) private var state

    var body: some View {
        Group {
            if let unit = state.selectedUnit {
                unitContent(unit)
            } else if let tile = selectedTile {
                tileContent(tile)
            } else {
                endTurnContent
            }
        }
        .frame(width: 250)
        .frame(minHeight: 90)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 3)
    }

    private var selectedTile: FreeColGame.Tile? {
        guard let game = state.game, let tileId = state.selectedTileId else { return nil }
        return game.tiles[tileId]
    }

    // MARK: - UNIT mode

    private func unitContent(_ unit: FreeColGame.Unit) -> some View {
        HStack(spacing: 10) {
            if let game = state.game,
               let nsImg = TileImageCache.shared.unitImage(forUnitType: unit.unitType) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            } else {
                let ownerColor = unit.owner.flatMap { playerColor(for: $0) } ?? .gray
                Circle()
                    .fill(ownerColor)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(.black, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayUnitName(unit.unitType))
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.white)
                Text("\(unit.state.rawValue)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text(movesLabel(unit))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .overlay(alignment: .bottom) {
            if !state.selectedUnitCargoUnits.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(state.selectedUnitCargoUnits.prefix(6)), id: \.id) { cargoUnit in
                        if let nsImg = TileImageCache.shared.unitImage(forUnitType: cargoUnit.unitType) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    if state.selectedUnitCargoUnits.count > 6 {
                        Text("+\(state.selectedUnitCargoUnits.count - 6)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func displayUnitName(_ unitType: String?) -> String {
        guard let unitType else { return "?" }
        if unitType.hasPrefix("model.unit.") {
            return String(unitType.dropFirst("model.unit.".count))
        }
        return unitType
    }

    private func movesLabel(_ unit: FreeColGame.Unit) -> String {
        if let game = state.game, game.tiles[unit.location ?? ""] == nil,
           unitLocationIsEurope(unit) {
            return "In Europe"
        }
        return "Moves: \(unit.movesLeft)"
    }

    private func unitLocationIsEurope(_ unit: FreeColGame.Unit) -> Bool {
        guard let game = state.game else { return false }
        if let loc = unit.location, game.units[loc] != nil { return false }
        if let loc = unit.location, game.tiles[loc] != nil { return false }
        return true
    }

    // MARK: - TILE mode

    private func tileContent(_ tile: FreeColGame.Tile) -> some View {
        HStack(spacing: 10) {
            if let nsImg = TileImageCache.shared.terrainImage(forType: tile.type) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 40)
                    .clipShape(DiamondShape())
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorForTileType(tile.type))
                    .frame(width: 56, height: 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(typeLabel(tile.type))
                    .font(.headline)
                    .foregroundColor(.white)
                if let ownerId = tile.owner, let game = state.game {
                    Text(game.players[ownerId]?.name ?? ownerId)
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                Text("(\(tile.x), \(tile.y))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func typeLabel(_ type: String?) -> String {
        guard let type else { return "?" }
        if type.hasPrefix("model.tile.") {
            return String(type.dropFirst("model.tile.".count))
        }
        return type
    }

    private func colorForTileType(_ type: String?) -> Color {
        let colors: [String: Color] = [
            "model.tile.ocean": .blue, "model.tile.plains": .green,
            "model.tile.grassland": .green, "model.tile.mountains": .gray,
            "model.tile.desert": .yellow, "model.tile.hills": .brown,
        ]
        guard let type else { return .gray }
        return colors[type] ?? .gray
    }

    // MARK: - END mode

    private var endTurnContent: some View {
        VStack(spacing: 8) {
            Text(state.isLocalPlayersTurn ? "Alle Einheiten fertig?" : "Warten auf Gegner…")
                .font(.caption)
                .foregroundColor(.white)
            Button("End Turn") {
                state.endTurn()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canEndTurn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

    private func playerColor(for playerId: String) -> Color? {
        guard let game = state.game else { return nil }
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(playerId.hashValue) % colors.count
        return colors[idx]
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}