import SwiftUI
import FreeColGame
import AppKit

private let baseTileW: Double = 64
private let baseTileH: Double = 32

// MARK: - Viewport reporting for the minimap

struct MapViewportInfo: Equatable {
    var canvasSize: CGSize
    var visibleRect: CGRect
}

struct MapViewportKey: PreferenceKey {
    static var defaultValue: MapViewportInfo?
    static func reduce(value: inout MapViewportInfo?, nextValue: () -> MapViewportInfo?) {
        if let nv = nextValue() { value = nv }
    }
}

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
    var bestTile: Tile?
    var bestScore: Double = .greatestFiniteMagnitude
    for tile in tiles {
        let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
        let dx = abs(location.x - origin.x) / halfW
        let dy = abs(location.y - origin.y) / halfH
        let score = dx + dy
        if score <= 1, score <= bestScore {
            bestScore = score
            bestTile = tile
        }
    }
    return bestTile
}

struct MapMouseCaptureView: NSViewRepresentable {
    var onLeftClick: (CGPoint) -> Void
    var onRightClick: (CGPoint) -> Void
    var onDrag: (CGSize) -> Void = { _ in }
    var onScroll: (CGSize) -> Void = { _ in }

    func makeNSView(context: Context) -> ClickCaptureNSView {
        let view = ClickCaptureNSView()
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        view.onDrag = onDrag
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ClickCaptureNSView, context: Context) {
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
        nsView.onDrag = onDrag
        nsView.onScroll = onScroll
    }
}

final class ClickCaptureNSView: NSView {
    var onLeftClick: ((CGPoint) -> Void)?
    var onRightClick: ((CGPoint) -> Void)?
    var onDrag: ((CGSize) -> Void)?
    var onScroll: ((CGSize) -> Void)?

    private var mouseDownPoint: CGPoint?
    private var lastPoint: CGPoint?
    private var didDrag = false

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownPoint = point
        lastPoint = point
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let last = lastPoint else { return }
        if let start = mouseDownPoint,
           abs(point.x - start.x) > 2 || abs(point.y - start.y) > 2 {
            didDrag = true
        }
        onDrag?(CGSize(width: point.x - last.x, height: point.y - last.y))
        lastPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag, let start = mouseDownPoint {
            onLeftClick?(start)
        }
        mouseDownPoint = nil
        lastPoint = nil
        didDrag = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
    }
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

    // Zoom: default 4.0 → tileW=256, tileH=128 (2× closer than the old 2.0 default).
    @State private var zoomScale: Double = 4.0
    private let minZoom: Double = 0.5
    private let maxZoom: Double = 5.0

    // Custom camera: canvas coordinate shown at the viewport's top-left.
    @State private var camera: CGPoint = .zero
    @State private var viewportSize: CGSize = .zero

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
        let visibleTileIds: Set<String>
    }

    private func renderData(for game: Game) -> RenderData? {
        guard game.map != nil else { return nil }
        let tiles = Array(game.tiles.values).sorted {
            if $0.y == $1.y { return $0.x < $1.x }
            return $0.y < $1.y
        }
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
        let visibleTileIds: Set<String>
        if let localPlayerId = state.localPlayerId {
            visibleTileIds = game.visibleTileIds(for: localPlayerId)
        } else {
            visibleTileIds = Set(tiles.map(\.id))
        }

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

        return RenderData(
            tiles: tiles,
            canvasSize: CGSize(width: canvasW, height: canvasH),
            playerColorById: playerColorById,
            unitsByTile: unitsByTile,
            visibleTileIds: visibleTileIds
        )
    }

    var body: some View {
        if let game = state.game, let data = renderData(for: game) {
            VStack(spacing: 0) {
                zoomControls
                GeometryReader { geo in
                    ZStack {
                        Canvas { ctx, _ in
                        ctx.translateBy(x: -camera.x, y: -camera.y)
                        for tile in data.tiles {
                            let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
                            let verts = diamondVertices(at: origin, tileW: tileW, tileH: tileH)
                            var path = Path()
                            path.addLines(verts)
                            path.closeSubpath()
                            let explored = tile.type != nil
                            let showFog = state.showFogOfWar
                            let isVisible = data.visibleTileIds.contains(tile.id)
                            let isDimmed = explored && !isVisible && showFog

                            // --- Terrain fill ---
                            let tileRect = CGRect(
                                x: origin.x - tileW / 2,
                                y: origin.y - tileH / 2,
                                width: tileW,
                                height: tileH
                            )
                            if !explored {
                                // Unexplored – draw original cloud texture
                                ctx.fill(path, with: .color(Color.black.opacity(0.78)))
                                if let cloudImg = TileImageCache.shared.cloudImage(forX: tile.x, y: tile.y) {
                                    var clipped = ctx
                                    clipped.clip(to: path)
                                    clipped.draw(Image(nsImage: cloudImg), in: tileRect)
                                }
                                continue
                            }
                            if tile.id == state.selectedTileId {
                                ctx.fill(path, with: .color(.yellow))
                            } else if let nsImg = TileImageCache.shared.terrainImage(forType: tile.type) {
                                var clipped = ctx
                                clipped.clip(to: path)
                                clipped.draw(Image(nsImage: nsImg), in: tileRect)
                            } else {
                                ctx.fill(path, with: .color(colorForTile(tile.type)))
                            }
                            // Explored but not currently visible: dim like the Java RescaleOp(0.8).
                            if isDimmed {
                                ctx.fill(path, with: .color(.black.opacity(0.2)))
                            }

                            // --- Border / owner outline ---
                            if state.showBorders,
                               let ownerId = tile.owner,
                               let ownerColor = data.playerColorById[ownerId] {
                                ctx.stroke(path, with: .color(ownerColor), lineWidth: 2)
                            }
                            if state.showMapGrid {
                                ctx.stroke(path, with: .color(.black.opacity(0.25)), lineWidth: 0.5)
                            }

                            // --- Colony label ---
                            if let colony = game.colonies.values.first(where: { $0.tileId == tile.id }) {
                                let labelText = "\(colony.name ?? "?") (\(colony.unitCount))"
                                let label = Text(labelText).font(.system(size: max(8, tileW * 0.12)))
                                    .foregroundColor(.white)
                                ctx.draw(label, at: origin, anchor: .center)
                            }
                            if let settlementInfo = tile.settlement {
                                let kind = settlementKind(for: settlementInfo, in: game)
                                if let nsImg = TileImageCache.shared.settlementImage(for: kind) {
                                    let fitted = fitSize(nsImg.size,
                                                         into: CGSize(width: tileW * 0.6,
                                                                      height: tileH * 0.75))
                                    let settlementRect = CGRect(
                                        x: origin.x - fitted.width / 2,
                                        y: origin.y - fitted.height * 0.65,
                                        width: fitted.width,
                                        height: fitted.height
                                    )
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
                            if isVisible || !showFog, let units = data.unitsByTile[tile.id] {
                                let count = units.count
                                for (i, unit) in units.enumerated() {
                                    let r: Double = max(5, tileH * 0.14)
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

                                    // Draw unit sprite on top if available, fitted to the tile.
                                    if let nsImg = TileImageCache.shared.unitImage(forUnitType: unit.unitType) {
                                        let fitted = fitSize(nsImg.size,
                                                             into: CGSize(width: tileW * 0.5,
                                                                          height: tileH * 0.95))
                                        let spriteRect = CGRect(
                                            x: ux - fitted.width / 2,
                                            y: uy - fitted.height * 0.8,
                                            width: fitted.width,
                                            height: fitted.height
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
                            .frame(width: geo.size.width, height: geo.size.height)
                            .background(Color(white: 0.08))

                            MapMouseCaptureView(
                                onLeftClick: { location in
                                    let canvasPoint = CGPoint(x: location.x + camera.x,
                                                              y: location.y + camera.y)
                                    handleLeftClick(at: canvasPoint, tiles: data.tiles, game: game)
                                },
                                onRightClick: { location in
                                    let canvasPoint = CGPoint(x: location.x + camera.x,
                                                              y: location.y + camera.y)
                                    handleRightClick(at: canvasPoint, tiles: data.tiles, game: game)
                                },
                                onDrag: { delta in
                                    camera = clampCamera(
                                        CGPoint(x: camera.x - delta.width, y: camera.y - delta.height),
                                        canvas: data.canvasSize
                                    )
                                },
                                onScroll: { delta in
                                    camera = clampCamera(
                                        CGPoint(x: camera.x - delta.width, y: camera.y - delta.height),
                                        canvas: data.canvasSize
                                    )
                                }
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .background(GeometryReader { _ in
                        Color.clear.preference(
                            key: MapViewportKey.self,
                            value: MapViewportInfo(
                                canvasSize: data.canvasSize,
                                visibleRect: CGRect(
                                    x: camera.x / zoomScale,
                                    y: camera.y / zoomScale,
                                    width: geo.size.width / zoomScale,
                                    height: geo.size.height / zoomScale
                                )
                            )
                        )
                    })
                    .onAppear {
                        viewportSize = geo.size
                        centerOnSelectedUnit(data: data)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        viewportSize = newSize
                        camera = clampCamera(camera, canvas: data.canvasSize)
                    }
                    .onChange(of: zoomScale) { _, _ in
                        centerOnSelectedUnit(data: data)
                    }
                    .onChange(of: state.selectedUnitTileId) { _, _ in
                        // Keep the camera on the active unit as it moves,
                        // but do not jump when the user merely inspects tiles.
                        centerOnSelectedUnit(data: data)
                    }
                    .onChange(of: state.gameUpdateID) { _, _ in
                        centerOnSelectedUnit(data: data)
                    }
                    .onChange(of: state.requestedMapScrollTileId) { _, newValue in
                        if let tileId = newValue {
                            centerCamera(on: tileId, data: data)
                            state.requestedMapScrollTileId = nil
                        }
                    }
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

    private func localUnits(onTile tileId: String, in game: Game) -> [FreeColGame.Unit] {
        guard let localPlayerId = state.localPlayerId else { return [] }
        return game.units.values
            .filter { $0.owner == localPlayerId && resolveUnitTileId($0, in: game) == tileId }
            .sorted { $0.id < $1.id }
    }

    private func handleLeftClick(at location: CGPoint, tiles: [Tile], game: Game) {
        guard let tappedTile = hitTest(location: location, tiles: tiles, tileW: tileW, tileH: tileH) else { return }
        let units = localUnits(onTile: tappedTile.id, in: game)
        guard !units.isEmpty else {
            state.selectUnit(nil, onTile: tappedTile.id)
            return
        }
        // Cycle through stacked units (e.g. ship + cargo) on repeated clicks.
        let next: FreeColGame.Unit
        if let currentId = state.selectedUnitId,
           let index = units.firstIndex(where: { $0.id == currentId }) {
            next = units[(index + 1) % units.count]
        } else {
            next = units[0]
        }
        state.selectUnit(next.id, onTile: tappedTile.id)
    }

    /// Scale an image's size down to fit within `maxSize`, preserving aspect ratio.
    private func fitSize(_ size: CGSize, into maxSize: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return maxSize }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private func clampCamera(_ point: CGPoint, canvas: CGSize) -> CGPoint {
        let maxX = max(0, canvas.width - viewportSize.width)
        let maxY = max(0, canvas.height - viewportSize.height)
        return CGPoint(x: min(max(point.x, 0), maxX), y: min(max(point.y, 0), maxY))
    }

    /// Move the camera so the given tile is centered in the viewport.
    private func centerCamera(on tileId: String, data: RenderData) {
        guard viewportSize.width > 0,
              let tile = data.tiles.first(where: { $0.id == tileId }) else { return }
        let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
        camera = clampCamera(
            CGPoint(x: origin.x - viewportSize.width / 2,
                    y: origin.y - viewportSize.height / 2),
            canvas: data.canvasSize
        )
    }

    /// Keep the camera on the active unit.
    private func centerOnSelectedUnit(data: RenderData) {
        guard let tileId = state.selectedUnitTileId else { return }
        centerCamera(on: tileId, data: data)
    }

    private func handleRightClick(at location: CGPoint, tiles: [Tile], game: Game) {
        guard let tappedTile = hitTest(location: location, tiles: tiles, tileW: tileW, tileH: tileH) else { return }

        if state.selectedUnitId == nil,
           let unit = localUnits(onTile: tappedTile.id, in: game).first {
            // Right-clicking an own unit without a selection selects it first.
            state.selectUnit(unit.id, onTile: tappedTile.id)
        } else if let selectedUnitId = state.selectedUnitId {
            // Keep the selected unit but retarget the tile for the popup.
            state.selectUnit(selectedUnitId, onTile: tappedTile.id)
        } else {
            state.selectUnit(nil, onTile: tappedTile.id)
        }

        // Java shows a TilePopup on right-click; movement is an entry in it.
        state.openTileActions(tappedTile.id)
    }
}
