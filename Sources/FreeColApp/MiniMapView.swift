import SwiftUI
import FreeColGame
import AppKit

/// Bottom-left minimap, modelled on the Java client's MiniMap:
/// terrain diamonds, fog overlay, viewport rectangle and click-to-center.
struct MiniMapView: View {
    @Environment(GameState.self) private var state
    var viewport: MapViewportInfo?

    var minimapWidth: Double = 160
    var maxMiniHeight: Double = 120

    private struct MiniData {
        let tiles: [Tile]
        let scale: Double
        let tileW: Double
        let tileH: Double
        let canvasSize: CGSize
        let visibleTileIds: Set<String>
        let unitsByTile: [String: [FreeColGame.Unit]]
        let playerColors: [String: Color]
        let colonyTiles: Set<String>
    }

    var body: some View {
        if let game = state.game, let data = miniData(for: game) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for tile in data.tiles {
                        let origin = miniOrigin(tile: tile, data: data)
                        let verts = miniDiamond(at: origin, tileW: data.tileW, tileH: data.tileH)
                        var path = Path()
                        path.addLines(verts)
                        path.closeSubpath()

                        let explored = tile.type != nil
                        let isVisible = data.visibleTileIds.contains(tile.id)
                        let showFog = state.showFogOfWar

                        // Settlement marker (70% diamond) in owner color.
                        let ownerColor = tile.owner.flatMap { data.playerColors[$0] }

                        if !explored {
                            ctx.fill(path, with: .color(Color(white: 0.15)))
                            if let ownerColor {
                                ctx.fill(path, with: .color(ownerColor.opacity(0.45)))
                            }
                        } else {
                            ctx.fill(path, with: .color(tile.moveToEurope
                                ? Color(red: 68.0 / 255, green: 68.0 / 255, blue: 110.0 / 255)
                                : miniColor(for: tile.type)))
                            if data.colonyTiles.contains(tile.id) {
                                var colonyPath = Path()
                                let s = 0.7
                                colonyPath.addLines([
                                    CGPoint(x: origin.x, y: origin.y - data.tileH / 2 * s),
                                    CGPoint(x: origin.x + data.tileW / 2 * s, y: origin.y),
                                    CGPoint(x: origin.x, y: origin.y + data.tileH / 2 * s),
                                    CGPoint(x: origin.x - data.tileW / 2 * s, y: origin.y),
                                ])
                                colonyPath.closeSubpath()
                                ctx.fill(colonyPath, with: .color(ownerColor ?? .white))
                                ctx.stroke(colonyPath, with: .color(.black), lineWidth: 1)
                            } else if (isVisible || !showFog), let units = data.unitsByTile[tile.id], let ownerColor {
                                // Half-size unit diamond in owner color.
                                var unitPath = Path()
                                unitPath.addLines([
                                    CGPoint(x: origin.x, y: origin.y - data.tileH / 4),
                                    CGPoint(x: origin.x + data.tileW / 4, y: origin.y),
                                    CGPoint(x: origin.x, y: origin.y + data.tileH / 4),
                                    CGPoint(x: origin.x - data.tileW / 4, y: origin.y),
                                ])
                                unitPath.closeSubpath()
                                ctx.fill(unitPath, with: .color(ownerColor))
                                ctx.stroke(unitPath, with: .color(.black), lineWidth: 0.6)
                            }
                            if !isVisible && showFog {
                                ctx.fill(path, with: .color(.black.opacity(0.35)))
                            }
                        }
                    }

                    // Viewport rectangle.
                    if let viewport, viewport.canvasSize.width > 0 {
                        let rect = viewport.visibleRect
                        let scale = data.scale
                        let vpRect = CGRect(
                            x: rect.minX * scale,
                            y: rect.minY * scale,
                            width: rect.width * scale,
                            height: rect.height * scale
                        )
                        ctx.stroke(
                            Path(CGRect(x: vpRect.minX + 0.5, y: vpRect.minY + 0.5,
                                        width: vpRect.width - 1, height: vpRect.height - 1)),
                            with: .color(.white),
                            lineWidth: 1.5
                        )
                    }
                }
                .frame(width: minimapWidth, height: minimapHeight(for: data))
                .clipped()
                .background(Color.black.opacity(0.4))
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleClick(at: value.location, data: data)
                        }
                )
            }
            .border(Color.gray.opacity(0.6), width: 1)
        } else {
            EmptyView()
        }
    }

    // MARK: - Data

    private func miniData(for game: Game) -> MiniData? {
        guard game.map != nil else { return nil }
        let tiles = Array(game.tiles.values).sorted {
            if $0.y == $1.y { return $0.x < $1.x }
            return $0.y < $1.y
        }
        guard !tiles.isEmpty else { return nil }
        let maxCol = tiles.map(\.x).max() ?? 0
        let maxRow = tiles.map(\.y).max() ?? 0
        let canvas = MapGeometry.canvasSize(maxX: maxCol, maxY: maxRow, tileW: 64, tileH: 32)
        // Aspect-fit: fit both the width and the height so the whole map is
        // visible and the viewport rectangle stays inside the minimap.
        let scale = min(minimapWidth / canvas.width, maxMiniHeight / canvas.height)

        let playerColors: [String: Color] = Dictionary(
            uniqueKeysWithValues: game.players.values.map { ($0.id, state.playerColor(for: $0.id)) }
        )

        var unitsByTile: [String: [FreeColGame.Unit]] = [:]
        for unit in game.units.values {
            guard let loc = unit.location else { continue }
            if game.tiles[loc] != nil {
                unitsByTile[loc, default: []].append(unit)
            } else if let carrier = game.units[loc], let carrierLoc = carrier.location,
                      game.tiles[carrierLoc] != nil {
                unitsByTile[carrierLoc, default: []].append(unit)
            }
        }

        let visibleTileIds: Set<String>
        if let localPlayerId = state.localPlayerId {
            visibleTileIds = game.visibleTileIds(for: localPlayerId)
        } else {
            visibleTileIds = Set(tiles.map(\.id))
        }

        let colonyTiles = Set(game.colonies.values.compactMap(\.tileId))

        return MiniData(
            tiles: tiles,
            scale: scale,
            tileW: 64 * scale,
            tileH: 32 * scale,
            canvasSize: canvas,
            visibleTileIds: visibleTileIds,
            unitsByTile: unitsByTile,
            playerColors: playerColors,
            colonyTiles: colonyTiles
        )
    }

    private func minimapHeight(for data: MiniData) -> Double {
        min(120, data.canvasSize.height * data.scale)
    }

    private func miniOrigin(tile: Tile, data: MiniData) -> CGPoint {
        MapGeometry.origin(x: tile.x, y: tile.y, tileW: data.tileW, tileH: data.tileH)
    }

    private func miniDiamond(at origin: CGPoint, tileW: Double, tileH: Double) -> [CGPoint] {
        [
            CGPoint(x: origin.x, y: origin.y - tileH / 2),
            CGPoint(x: origin.x + tileW / 2, y: origin.y),
            CGPoint(x: origin.x, y: origin.y + tileH / 2),
            CGPoint(x: origin.x - tileW / 2, y: origin.y),
        ]
    }

    private func handleClick(at location: CGPoint, data: MiniData) {
        var best: (tile: Tile, score: Double)?
        for tile in data.tiles {
            let origin = miniOrigin(tile: tile, data: data)
            let dx = abs(location.x - origin.x) / (data.tileW / 2)
            let dy = abs(location.y - origin.y) / (data.tileH / 2)
            let score = Double(dx + dy)
            if score <= 1, score < (best?.score ?? .infinity) {
                best = (tile, score)
            }
        }
        if let tile = best?.tile {
            state.requestMapScroll(to: tile.id)
        }
    }

    // MARK: - Colors

    private func miniColor(for type: String?) -> Color {
        let colors: [String: Color] = [
            "model.tile.ocean": Color(red: 0.2, green: 0.4, blue: 0.8),
            "model.tile.highSeas": Color(red: 0.2, green: 0.4, blue: 0.8),
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
        guard let type else { return .gray }
        return colors[type] ?? .gray
    }

}