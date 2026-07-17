import SwiftUI
import FreeColGame

private let baseTileW: Double = 64
private let baseTileH: Double = 32

private func tileOrigin(x: Int, y: Int, tileW: Double, tileH: Double) -> CGPoint {
    let colW = tileW / 2
    let rowH = tileH / 2
    let offsetX = y.isMultiple(of: 2) ? 0.0 : colW
    return CGPoint(
        x: Double(x) * colW + offsetX + colW,
        y: Double(y) * rowH + rowH
    )
}

private func diamondVertices(at origin: CGPoint, tileW: Double, tileH: Double) -> [CGPoint] {
    [
        CGPoint(x: origin.x,             y: origin.y - tileH / 2),
        CGPoint(x: origin.x + tileW / 2, y: origin.y),
        CGPoint(x: origin.x,             y: origin.y + tileH / 2),
        CGPoint(x: origin.x - tileW / 2, y: origin.y),
    ]
}

private func hitTest(location: CGPoint, tiles: [Tile], tileW: Double, tileH: Double) -> Tile? {
    let halfW = tileW / 2
    let halfH = tileH / 2
    for tile in tiles {
        let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
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

    // Zoom: default 2.0 → tileW=128, tileH=64 → ~15 tiles visible in an 800px-wide panel
    @State private var zoomScale: Double = 2.0
    private let minZoom: Double = 0.5
    private let maxZoom: Double = 5.0

    private var tileW: Double { baseTileW * zoomScale }
    private var tileH: Double { baseTileH * zoomScale }

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
        let colW = tileW / 2
        let rowH = tileH / 2
        let maxCol = tiles.map(\.x).max() ?? 0
        let maxRow = tiles.map(\.y).max() ?? 0
        let canvasW = Double(maxCol + 2) * colW + tileW
        let canvasH = Double(maxRow + 1) * rowH + tileH

        let playerColorById: [String: Color] = Dictionary(
            uniqueKeysWithValues: game.players.values.map { ($0.id, colorForPlayer($0)) }
        )

        // Build a tile-keyed unit map, resolving indirect locations:
        // - Unit directly on tile: location == tileId
        // - Unit on carrier (ship): location == carrierId → carrier.location == tileId
        // - Unit in colony building: location == colony/buildingId → colony.tileId
        var unitsByTile: [String: [FreeColGame.Unit]] = [:]
        for unit in game.units.values {
            guard let loc = unit.location else { continue }
            if game.tiles[loc] != nil {
                unitsByTile[loc, default: []].append(unit)
            } else if let carrier = game.units[loc],
                      let carrierLoc = carrier.location,
                      game.tiles[carrierLoc] != nil {
                // Embarked on a ship — show on the ship's tile
                unitsByTile[carrierLoc, default: []].append(unit)
            } else if let colony = game.colonies[loc], let tileId = colony.tileId {
                // Working inside a colony building
                unitsByTile[tileId, default: []].append(unit)
            }
        }

        // Debug: log unit placement summary
        let totalUnits = game.units.count
        let placedUnits = unitsByTile.values.reduce(0) { $0 + $1.count }
        if totalUnits > 0 {
            print("[MapView] units in game: \(totalUnits), placed on map: \(placedUnits)")
            for unit in game.units.values.prefix(3) {
                print("[MapView]   unit \(unit.id) type=\(unit.unitType ?? "nil") loc=\(unit.location ?? "nil")")
            }
            if let sampleTileId = tiles.first?.id {
                print("[MapView]   sample tileId=\(sampleTileId)")
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
            VStack(spacing: 0) {
                zoomControls
                ScrollView([.horizontal, .vertical]) {
                    Canvas { ctx, _ in
                        for tile in data.tiles {
                            let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
                            let verts = diamondVertices(at: origin, tileW: tileW, tileH: tileH)
                            var path = Path()
                            path.addLines(verts)
                            path.closeSubpath()

                            // --- Terrain fill ---
                            let tileRect = CGRect(
                                x: origin.x - tileW / 2,
                                y: origin.y - tileH / 2,
                                width: tileW,
                                height: tileH
                            )
                            if tile.id == state.selectedTileId {
                                ctx.fill(path, with: .color(.yellow))
                            } else if let nsImg = TileImageCache.shared.terrainImage(forType: tile.type) {
                                var clipped = ctx
                                clipped.clip(to: path)
                                clipped.draw(Image(nsImage: nsImg), in: tileRect)
                            } else {
                                ctx.fill(path, with: .color(colorForTile(tile.type)))
                            }

                            // --- Border / owner outline ---
                            if let ownerId = tile.owner, let ownerColor = data.playerColorById[ownerId] {
                                ctx.stroke(path, with: .color(ownerColor), lineWidth: 2)
                            } else {
                                ctx.stroke(path, with: .color(.black.opacity(0.25)), lineWidth: 0.5)
                            }

                            // --- Settlement ---
                            if let settlementInfo = tile.settlement {
                                let kind = settlementKind(for: settlementInfo, in: game)
                                let settlementH: Double = tileH * 0.8
                                let settlementW: Double = tileW * 0.55
                                let settlementRect = CGRect(
                                    x: origin.x - settlementW / 2,
                                    y: origin.y - settlementH * 0.75,
                                    width: settlementW,
                                    height: settlementH
                                )
                                if let nsImg = TileImageCache.shared.settlementImage(for: kind) {
                                    ctx.draw(Image(nsImage: nsImg), in: settlementRect)
                                } else {
                                    let s: Double = max(8, tileW * 0.18)
                                    let marker = Path(roundedRect: CGRect(
                                        x: origin.x - s / 2, y: origin.y - s / 2,
                                        width: s, height: s
                                    ), cornerSize: CGSize(width: 2, height: 2))
                                    ctx.fill(marker, with: .color(.white))
                                    ctx.stroke(marker, with: .color(.black), lineWidth: 1)
                                }
                            }

                            // --- Units ---
                            if let units = data.unitsByTile[tile.id] {
                                let count = units.count
                                for (i, unit) in units.enumerated() {
                                    let r: Double = max(6, tileH * 0.18)
                                    let spacing: Double = min(r * 2.5, tileW / Double(max(count, 1)))
                                    let startX = origin.x - spacing * Double(count - 1) / 2.0
                                    let ux = startX + spacing * Double(i)
                                    let uy = origin.y

                                    let isSelected = unit.id == state.selectedUnitId
                                    let ownerColor = unit.owner.flatMap { data.playerColorById[$0] } ?? .white

                                    // Always draw a colored dot so units are visible even without sprites
                                    let dotRect = CGRect(x: ux - r, y: uy - r, width: r * 2, height: r * 2)
                                    if isSelected {
                                        ctx.fill(Path(ellipseIn: dotRect.insetBy(dx: -4, dy: -4)), with: .color(.yellow.opacity(0.8)))
                                    }
                                    ctx.fill(Path(ellipseIn: dotRect), with: .color(ownerColor))
                                    ctx.stroke(Path(ellipseIn: dotRect), with: .color(.black), lineWidth: 1.5)

                                    // Draw unit sprite on top if available
                                    if let nsImg = TileImageCache.shared.unitImage(forUnitType: unit.unitType) {
                                        let imgSize = nsImg.size
                                        let aspect = imgSize.width > 0 ? imgSize.height / imgSize.width : 1.0
                                        let spriteW: Double = tileW * 0.5
                                        let spriteH: Double = spriteW * aspect
                                        let spriteRect = CGRect(
                                            x: ux - spriteW / 2,
                                            y: uy - spriteH * 0.9,
                                            width: spriteW,
                                            height: spriteH
                                        )
                                        ctx.draw(Image(nsImage: nsImg), in: spriteRect)
                                    }
                                }
                            }
                        }

                        if let selectedUnitId = state.selectedUnitId,
                           let selectedUnit = game.units[selectedUnitId],
                           let destinationTileId = selectedUnit.destination,
                           let destinationTile = data.tiles.first(where: { $0.id == destinationTileId }),
                           let sourceTileId = resolveUnitTileId(selectedUnit, in: game),
                           let sourceTile = data.tiles.first(where: { $0.id == sourceTileId }) {
                            let sourceOrigin = tileOrigin(x: sourceTile.x, y: sourceTile.y, tileW: tileW, tileH: tileH)
                            let destinationOrigin = tileOrigin(x: destinationTile.x, y: destinationTile.y, tileW: tileW, tileH: tileH)

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

                            let markerSize = max(10, tileW * 0.15)
                            let markerRect = CGRect(
                                x: destinationOrigin.x - markerSize / 2,
                                y: destinationOrigin.y - markerSize / 2,
                                width: markerSize,
                                height: markerSize
                            )
                            let marker = Path(ellipseIn: markerRect)
                            ctx.stroke(marker, with: .color(.yellow), lineWidth: 2)
                        }

                        if let cue = state.mapAnimationCue,
                           let sourceTile = data.tiles.first(where: { $0.id == cue.sourceTileId }),
                           let targetTile = data.tiles.first(where: { $0.id == cue.targetTileId }) {
                            let source = tileOrigin(x: sourceTile.x, y: sourceTile.y, tileW: tileW, tileH: tileH)
                            let target = tileOrigin(x: targetTile.x, y: targetTile.y, tileW: tileW, tileH: tileH)

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

                            let pulseR = max(9, tileW * 0.12)
                            let pulse = Path(ellipseIn: CGRect(x: target.x - pulseR, y: target.y - pulseR, width: pulseR * 2, height: pulseR * 2))
                            ctx.stroke(pulse, with: .color(color), lineWidth: 2)
                        }

                        // Selection highlight outline
                        if let selId = state.selectedTileId,
                           let selTile = data.tiles.first(where: { $0.id == selId }) {
                            let origin = tileOrigin(x: selTile.x, y: selTile.y, tileW: tileW, tileH: tileH)
                            let verts = diamondVertices(at: origin, tileW: tileW, tileH: tileH)
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
            }
        } else {
            Text("No map loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button {
                zoomScale = max(minZoom, zoomScale / 1.4)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)

            Text("\(Int(zoomScale * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 44)

            Button {
                zoomScale = min(maxZoom, zoomScale * 1.4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)

            Button {
                zoomScale = 2.0
            } label: {
                Text("Reset")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.12))
    }

    private func settlementKind(for settlementId: String, in game: Game) -> SettlementKind {
        guard let colony = game.colonies[settlementId] else { return .nativeCamp }
        let type = colony.settlementType?.lowercased() ?? ""
        if type.contains("aztec") { return .aztecCity }
        if type.contains("inca") { return .incaCity }
        if type.contains("indian") || type.contains("native") {
            return colony.unitCount >= 3 ? .nativeVillage : .nativeCamp
        }
        // European colony — size by population
        let pop = colony.unitCount
        if pop >= 15 { return .colony(size: 3) }
        if pop >= 8  { return .colony(size: 2) }
        return .colony(size: 1)
    }

    private func handleTap(at location: CGPoint, tiles: [Tile], game: Game) {
        guard let tappedTile = hitTest(location: location, tiles: tiles, tileW: tileW, tileH: tileH) else { return }

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
        if let localPlayerId = state.localPlayerId,
           let unit = game.units.values.first(where: {
               $0.location == tappedTile.id && $0.owner == localPlayerId
           }) {
            state.selectUnit(unit.id, onTile: tappedTile.id)
        } else {
            state.selectUnit(nil, onTile: tappedTile.id)
        }
    }
}
