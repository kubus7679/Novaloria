import SwiftUI
import FreeColGame

private let tileW: Double = 64
private let tileH: Double = 32
private let colW: Double = tileW / 2
private let rowH: Double = tileH / 2

private func tileOrigin(x: Int, y: Int) -> CGPoint {
    let offsetX = y.isMultiple(of: 2) ? 0.0 : colW
    return CGPoint(
        x: Double(x) * colW + offsetX + colW,
        y: Double(y) * rowH + rowH
    )
}

private func diamondVertices(at origin: CGPoint) -> [CGPoint] {
    [
        CGPoint(x: origin.x,           y: origin.y - tileH / 2),
        CGPoint(x: origin.x + tileW / 2, y: origin.y),
        CGPoint(x: origin.x,           y: origin.y + tileH / 2),
        CGPoint(x: origin.x - tileW / 2, y: origin.y),
    ]
}

private func hitTest(location: CGPoint, tiles: [Tile]) -> Tile? {
    let halfW = tileW / 2
    let halfH = tileH / 2
    for tile in tiles {
        let origin = tileOrigin(x: tile.x, y: tile.y)
        let dx = abs(location.x - origin.x) / halfW
        let dy = abs(location.y - origin.y) / halfH
        if dx + dy <= 1 {
            return tile
        }
    }
    return nil
}

private let tileColors: [String: Color] = [
    "model.tile.ocean": Color(red: 0.2, green: 0.4, blue: 0.8),
    "model.tile.plains": Color(red: 0.8, green: 0.75, blue: 0.4),
    "model.tile.grassland": Color(red: 0.4, green: 0.7, blue: 0.3),
    "model.tile.desert": Color(red: 0.85, green: 0.75, blue: 0.5),
    "model.tile.hills": Color(red: 0.6, green: 0.55, blue: 0.35),
    "model.tile.mountains": Color(red: 0.45, green: 0.4, blue: 0.35),
    "model.tile.tundra": Color(red: 0.6, green: 0.65, blue: 0.6),
    "model.tile.swamp": Color(red: 0.3, green: 0.5, blue: 0.25),
    "model.tile.borealForest": Color(red: 0.2, green: 0.4, blue: 0.2),
    "model.tile.tropicalForest": Color(red: 0.15, green: 0.5, blue: 0.15),
    "model.tile.savannah": Color(red: 0.75, green: 0.7, blue: 0.3),
    "model.tile.marsh": Color(red: 0.35, green: 0.55, blue: 0.3),
    "model.tile.lake": Color(red: 0.25, green: 0.45, blue: 0.8),
    "model.tile.river": Color(red: 0.2, green: 0.4, blue: 0.75),
    "model.tile.beach": Color(red: 0.9, green: 0.85, blue: 0.6),
]

private func colorForTile(_ type: String?) -> Color {
    guard let type = type else { return .gray }
    return tileColors[type] ?? Color(hue: Double(abs(type.hashValue) % 360) / 360, saturation: 0.3, brightness: 0.6)
}

private let playerColors: [Color] = [
    .blue, .red, .green, .orange, .purple, .brown, .cyan, .mint, .pink, .yellow
]

private func colorForPlayer(_ player: Player) -> Color {
    let idx = abs(player.id.hashValue) % playerColors.count
    return playerColors[idx]
}

struct MapView: View {
    @Environment(GameState.self) private var state

    private func resolveUnitTileId(_ unit: FreeColGame.Unit, in game: Game) -> String? {
        if let loc = unit.location, game.tiles[loc] != nil {
            return loc
        }
        if let carrierId = unit.location,
           let carrier = game.units[carrierId],
           let carrierTileId = carrier.location,
           game.tiles[carrierTileId] != nil {
            return carrierTileId
        }
        return nil
    }

    private struct RenderData {
        let tiles: [Tile]
        let canvasSize: CGSize
        let playerColorById: [String: Color]
        let unitsByTile: [String: [FreeColGame.Unit]]
    }

    private func renderData(for game: Game) -> RenderData? {
        guard game.map != nil else { return nil }
        let tiles = Array(game.tiles.values)
        guard !tiles.isEmpty else { return nil }
        let maxCol = tiles.map(\.x).max() ?? 0
        let maxRow = tiles.map(\.y).max() ?? 0
        let canvasW = Double(maxCol + 2) * colW + tileW
        let canvasH = Double(maxRow + 1) * rowH + tileH

        let playerColorById: [String: Color] = Dictionary(
            uniqueKeysWithValues: game.players.values.map { ($0.id, colorForPlayer($0)) }
        )

        var unitsByTile: [String: [FreeColGame.Unit]] = [:]
        for unit in game.units.values {
            if let loc = unit.location {
                unitsByTile[loc, default: []].append(unit)
            }
        }

        return RenderData(
            tiles: tiles,
            canvasSize: CGSize(width: canvasW, height: canvasH),
            playerColorById: playerColorById,
            unitsByTile: unitsByTile
        )
    }

    var body: some View {
        if let game = state.game, let data = renderData(for: game) {
            ScrollView([.horizontal, .vertical]) {
                Canvas { ctx, _ in
                    for tile in data.tiles {
                        let origin = tileOrigin(x: tile.x, y: tile.y)
                        let verts = diamondVertices(at: origin)
                        var path = Path()
                        path.addLines(verts)
                        path.closeSubpath()

                        let fill = colorForTile(tile.type)

                        if tile.id == state.selectedTileId {
                            ctx.fill(path, with: .color(.yellow))
                        } else {
                            ctx.fill(path, with: .color(fill))
                        }

                        if let ownerId = tile.owner, let ownerColor = data.playerColorById[ownerId] {
                            ctx.stroke(path, with: .color(ownerColor), lineWidth: 2)
                        } else {
                            ctx.stroke(path, with: .color(fill.opacity(0.8)), lineWidth: 0.5)
                        }

                        if tile.settlement != nil {
                            let s: Double = 12
                            let marker = Path(roundedRect: CGRect(
                                x: origin.x - s / 2,
                                y: origin.y - s / 2,
                                width: s,
                                height: s
                            ), cornerSize: CGSize(width: 2, height: 2))
                            ctx.fill(marker, with: .color(.white))
                            ctx.stroke(marker, with: .color(.black), lineWidth: 1)
                        }

                        if let units = data.unitsByTile[tile.id] {
                            for (i, unit) in units.enumerated() {
                                let r: Double = 5
                                let ux = origin.x + Double(i - units.count / 2) * (r * 2 + 1)
                                let uy = origin.y + tileH / 4
                                let dot = Path(ellipseIn: CGRect(
                                    x: ux - r,
                                    y: uy - r,
                                    width: r * 2,
                                    height: r * 2
                                ))
                                let ownerColor = unit.owner.flatMap { data.playerColorById[$0] } ?? .white

                                if unit.id == state.selectedUnitId {
                                    ctx.fill(dot, with: .color(.yellow))
                                } else {
                                    ctx.fill(dot, with: .color(ownerColor))
                                }
                                ctx.stroke(dot, with: .color(.black), lineWidth: 1)
                            }
                        }
                    }

                    if let selectedUnitId = state.selectedUnitId,
                       let selectedUnit = game.units[selectedUnitId],
                       let destinationTileId = selectedUnit.destination,
                       let destinationTile = data.tiles.first(where: { $0.id == destinationTileId }),
                       let sourceTileId = resolveUnitTileId(selectedUnit, in: game),
                       let sourceTile = data.tiles.first(where: { $0.id == sourceTileId }) {
                        let sourceOrigin = tileOrigin(x: sourceTile.x, y: sourceTile.y)
                        let destinationOrigin = tileOrigin(x: destinationTile.x, y: destinationTile.y)

                        if sourceTileId != destinationTileId {
                            var previewPath = Path()
                            previewPath.move(to: sourceOrigin)
                            previewPath.addLine(to: destinationOrigin)
                            ctx.stroke(
                                previewPath,
                                with: .color(.yellow.opacity(0.9)),
                                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                            )
                        }

                        let markerRect = CGRect(
                            x: destinationOrigin.x - 7,
                            y: destinationOrigin.y - 7,
                            width: 14,
                            height: 14
                        )
                        let marker = Path(ellipseIn: markerRect)
                        ctx.stroke(marker, with: .color(.yellow), lineWidth: 2)
                    }

                    if let cue = state.mapAnimationCue,
                       let sourceTile = data.tiles.first(where: { $0.id == cue.sourceTileId }),
                       let targetTile = data.tiles.first(where: { $0.id == cue.targetTileId }) {
                        let source = tileOrigin(x: sourceTile.x, y: sourceTile.y)
                        let target = tileOrigin(x: targetTile.x, y: targetTile.y)

                        let color: Color
                        let lineWidth: Double
                        switch cue.style {
                        case .move:
                            color = .cyan
                            lineWidth = 3
                        case .attack:
                            color = .red
                            lineWidth = 3
                        case .attackSuccess:
                            color = .green
                            lineWidth = 3
                        case .attackFail:
                            color = .orange
                            lineWidth = 3
                        }

                        var line = Path()
                        line.move(to: source)
                        line.addLine(to: target)
                        ctx.stroke(line, with: .color(color.opacity(0.95)), style: StrokeStyle(lineWidth: lineWidth, dash: [4, 3]))

                        let pulse = Path(ellipseIn: CGRect(x: target.x - 9, y: target.y - 9, width: 18, height: 18))
                        ctx.stroke(pulse, with: .color(color), lineWidth: 2)
                    }

                    // Selection highlight outline
                    if let selId = state.selectedTileId,
                       let selTile = data.tiles.first(where: { $0.id == selId }) {
                        let origin = tileOrigin(x: selTile.x, y: selTile.y)
                        let verts = diamondVertices(at: origin)
                        var selPath = Path()
                        selPath.addLines(verts)
                        selPath.closeSubpath()
                        ctx.stroke(selPath, with: .color(.white), lineWidth: 3)
                    }
                }
                .frame(width: data.canvasSize.width, height: data.canvasSize.height)
                .background(Color(white: 0.08))
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleTap(at: value.location, tiles: data.tiles, game: game)
                        }
                )
            }
        } else {
            Text("No map loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleTap(at location: CGPoint, tiles: [Tile], game: Game) {
        guard let tappedTile = hitTest(location: location, tiles: tiles) else { return }

        if let selId = state.selectedUnitId,
           let selectedUnit = game.units[selId] {
            // If an embarked unit is selected and the carrier tile is tapped, disembark.
            if state.canDisembarkSelectedUnit,
               state.selectedTileId == tappedTile.id {
                state.disembarkSelectedUnit()
                return
            }

            // Tapping the same tile → deselect
            if selectedUnit.location == tappedTile.id {
                if state.canJoinSelectedColony {
                    state.joinSelectedColony()
                    return
                }
                if let carrierId = state.defaultEmbarkCarrierId,
                   state.canEmbarkSelectedUnit(onCarrier: carrierId) {
                    state.embarkSelectedUnit(onCarrier: carrierId)
                    return
                }
                state.selectUnit(nil, onTile: nil)
                return
            }
            // Tapping a different tile → move selected unit there
            if state.canAttackSelectedUnitMelee(onTile: tappedTile.id) {
                state.attackSelectedUnitMelee(onTile: tappedTile.id)
            } else if state.canAttackSelectedUnitRanged(onTile: tappedTile.id) {
                state.attackSelectedUnitRanged(onTile: tappedTile.id)
            } else if state.canMoveSelectedUnit(to: tappedTile.id) {
                state.moveSelectedUnit(to: tappedTile.id)
            } else {
                // Keep tile focus for inspection when move is currently illegal.
                state.selectUnit(selId, onTile: tappedTile.id)
            }
            return
        }

        // No unit selected: pick the first own unit on the tapped tile
        if let unit = game.units.values.first(where: {
            $0.location == tappedTile.id && $0.owner == game.currentPlayerId
        }) {
            state.selectUnit(unit.id, onTile: tappedTile.id)
        } else {
            state.selectUnit(nil, onTile: tappedTile.id)
        }
    }
}
