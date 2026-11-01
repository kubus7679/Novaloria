import SwiftUI
import FreeColGame
import AppKit
import os

private let mapRenderLog = OSLog(subsystem: "org.freecol.client", category: "MapRendering")

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
    MapGeometry.origin(x: x, y: y, tileW: tileW, tileH: tileH)
}

private func diamondVertices(at origin: CGPoint, tileW: Double, tileH: Double) -> [CGPoint] {
    [
        CGPoint(x: origin.x,             y: origin.y - tileH / 2),
        CGPoint(x: origin.x + tileW / 2, y: origin.y),
        CGPoint(x: origin.x,             y: origin.y + tileH / 2),
        CGPoint(x: origin.x - tileW / 2, y: origin.y),
    ]
}

struct MapMouseCaptureView: NSViewRepresentable {
    var onLeftClick: (CGPoint) -> Void
    var onRightClick: (CGPoint) -> Void
    var onDoubleClick: (CGPoint) -> Void = { _ in }
    var onDrag: (CGSize) -> Void = { _ in }
    var onScroll: (CGSize) -> Void = { _ in }

    func makeNSView(context: Context) -> ClickCaptureNSView {
        let view = ClickCaptureNSView()
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        view.onDoubleClick = onDoubleClick
        view.onDrag = onDrag
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ClickCaptureNSView, context: Context) {
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onDrag = onDrag
        nsView.onScroll = onScroll
    }
}

final class ClickCaptureNSView: NSView {
    var onLeftClick: ((CGPoint) -> Void)?
    var onRightClick: ((CGPoint) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    var onDrag: ((CGSize) -> Void)?
    var onScroll: ((CGSize) -> Void)?

    private var mouseDownPoint: CGPoint?
    private var lastPoint: CGPoint?
    private var didDrag = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        if didDrag {
            onDrag?(CGSize(width: point.x - last.x, height: point.y - last.y))
        }
        lastPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag, let start = mouseDownPoint {
            if event.clickCount == 2 {
                onDoubleClick?(start)
            } else {
                onLeftClick?(start)
            }
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
    return tileColors[type] ?? .gray
}

struct MapView: View {
    @Environment(GameState.self) private var state

    @State private var zoomScale: Double = 2.0
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
        let colonyByTile: [String: Colony]
        let tileIndex: TileSpatialIndex
        let visibleTileIds: Set<String>
    }

    private func renderData(for game: Game) -> RenderData? {
        let signpostID = OSSignpostID(log: mapRenderLog)
        os_signpost(.begin, log: mapRenderLog, name: "RenderDataBuild", signpostID: signpostID)
        defer {
            os_signpost(.end, log: mapRenderLog, name: "RenderDataBuild", signpostID: signpostID)
        }

        guard game.map != nil else { return nil }
        let tiles = Array(game.tiles.values).sorted {
            if $0.y == $1.y { return $0.x < $1.x }
            return $0.y < $1.y
        }
        guard !tiles.isEmpty else { return nil }
        let maxCol = tiles.map(\.x).max() ?? 0
        let maxRow = tiles.map(\.y).max() ?? 0

        let playerColorById: [String: Color] = Dictionary(
            uniqueKeysWithValues: game.players.values.map { ($0.id, state.playerColor(for: $0.id)) }
        )
        let visibleTileIds: Set<String>
        if let localPlayerId = state.localPlayerId {
            visibleTileIds = game.visibleTileIds(for: localPlayerId)
        } else {
            visibleTileIds = Set(tiles.map(\.id))
        }

        // Passengers and indoor workers are shown in their carrier/colony inspector.
        var unitsByTile: [String: [FreeColGame.Unit]] = [:]
        for unit in game.units.values {
            guard let loc = unit.location else { continue }
            if game.tiles[loc] != nil {
                unitsByTile[loc, default: []].append(unit)
            }
        }

        var colonyByTile: [String: Colony] = [:]
        for colony in game.colonies.values {
            guard let tileId = colony.tileId, colonyByTile[tileId] == nil else { continue }
            colonyByTile[tileId] = colony
        }

        return RenderData(
            tiles: tiles,
            canvasSize: MapGeometry.canvasSize(maxX: maxCol, maxY: maxRow, tileW: tileW, tileH: tileH),
            playerColorById: playerColorById,
            unitsByTile: unitsByTile,
            colonyByTile: colonyByTile,
            tileIndex: TileSpatialIndex(sortedTiles: tiles),
            visibleTileIds: visibleTileIds
        )
    }

    var body: some View {
        if let game = state.game, let data = renderData(for: game) {
            VStack(spacing: 0) {
                zoomControls
                GeometryReader { geo in
                    ZStack {
                        Canvas { ctx, size in
                        let signpostID = OSSignpostID(log: mapRenderLog)
                        os_signpost(.begin, log: mapRenderLog, name: "CanvasCommands", signpostID: signpostID)
                        defer {
                            os_signpost(.end, log: mapRenderLog, name: "CanvasCommands", signpostID: signpostID)
                        }

                        ctx.translateBy(x: -camera.x, y: -camera.y)
                        let visibleTiles = data.tileIndex.visibleTiles(
                            in: CGRect(origin: camera, size: size),
                            tileW: tileW,
                            tileH: tileH
                        )
                        for tile in visibleTiles {
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
                            if let nsImg = TileImageCache.shared.terrainImage(forType: tile.type) {
                                var clipped = ctx
                                clipped.clip(to: path)
                                clipped.draw(Image(nsImage: nsImg), in: tileRect)
                            } else {
                                ctx.fill(path, with: .color(colorForTile(tile.type)))
                            }
                            if ["model.tile.ocean", "model.tile.lake", "model.tile.highSeas", "model.tile.greatRiver"]
                                .contains(tile.type ?? "") {
                                for beach in TileImageCache.shared.beachImages(style: tile.style) {
                                    ctx.draw(Image(nsImage: beach), in: tileRect)
                                }
                            }
                            if let overlay = TileImageCache.shared.terrainOverlay(forType: tile.type) {
                                let height = tileW * overlay.size.height / max(1, overlay.size.width)
                                ctx.draw(Image(nsImage: overlay), in: CGRect(
                                    x: tileRect.minX, y: tileRect.maxY - height, width: tileW, height: height
                                ))
                            }
                            drawImprovements(tile, at: origin, context: &ctx)
                            for resource in tile.resources {
                                if let image = TileImageCache.shared.resourceImage(for: resource.type) {
                                    let width = tileW * 0.4
                                    let height = width * image.size.height / max(1, image.size.width)
                                    ctx.draw(Image(nsImage: image), in: CGRect(
                                        x: origin.x - width / 2, y: origin.y - height / 2,
                                        width: width, height: height
                                    ))
                                }
                            }
                            if let image = TileImageCache.shared.lostCityRumourImage(for: tile) {
                                let width = tileW * 0.5
                                let height = width * image.size.height / max(1, image.size.width)
                                ctx.draw(Image(nsImage: image), in: CGRect(
                                    x: origin.x - width / 2, y: origin.y - height / 2,
                                    width: width, height: height
                                ))
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
                            if tile.id == state.selectedTileId {
                                ctx.stroke(path, with: .color(.white), lineWidth: 3)
                                ctx.stroke(path, with: .color(.yellow), lineWidth: 1)
                            }

                            let hasSettlement = tile.settlement != nil || data.colonyByTile[tile.id] != nil
                            if let settlementInfo = tile.settlement ?? data.colonyByTile[tile.id]?.id {
                                let kind = settlementKind(for: settlementInfo, in: game)
                                if let nsImg = TileImageCache.shared.settlementImage(for: kind) {
                                    let fitted = fitSize(nsImg.size,
                                                         into: CGSize(width: tileW * 0.6,
                                                                      height: tileH * 0.75))
                                    let settlementRect = CGRect(
                                        x: origin.x - fitted.width / 2 - (data.unitsByTile[tile.id]?.isEmpty == false ? tileW * 0.16 : 0),
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
                                let sorted = units.sorted { $0.id < $1.id }
                                if let unit = sorted.first(where: { $0.id == state.selectedUnitId }) ?? sorted.first {
                                    let r: Double = max(5, tileH * 0.14)
                                    let ux = origin.x + (hasSettlement ? tileW * 0.24 : 0)
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
                                    let badge = CGRect(x: ux + r, y: uy - tileH * 0.55,
                                                       width: max(14, tileW * 0.16), height: max(12, tileH * 0.3))
                                    ctx.fill(Path(roundedRect: badge, cornerRadius: 3), with: .color(ownerColor))
                                    ctx.stroke(Path(roundedRect: badge, cornerRadius: 3), with: .color(.black), lineWidth: 1)
                                    ctx.draw(Text("\(units.count)").font(.system(size: max(9, tileW * 0.09), weight: .bold))
                                        .foregroundColor(.white), at: CGPoint(x: badge.midX, y: badge.midY))
                                }
                            }

                            if state.mapOverlay == .resources,
                               (isVisible || !showFog),
                               let resource = tile.resources.first {
                                let quantity = resource.quantity >= 0 ? " ×\(resource.quantity)" : ""
                                let label = Text("\(GameLabels.name(resource.type ?? resource.id))\(quantity)")
                                    .font(.system(size: max(8, tileW * 0.055), weight: .bold))
                                    .foregroundColor(.white)
                                ctx.draw(label, at: CGPoint(x: origin.x, y: origin.y + tileH * 0.4))
                            }
                        }

                        for tile in visibleTiles {
                            guard let image = TileImageCache.shared.highSeasExitImage(for: tile) else { continue }
                            let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
                            let height = tileW * image.size.height / max(1, image.size.width)
                            ctx.draw(Image(nsImage: image), in: CGRect(
                                x: origin.x - tileW / 2, y: origin.y - height / 2,
                                width: tileW, height: height
                            ))
                        }

                        // Labels must follow all sprites so later tiles cannot paint over them.
                        for tile in visibleTiles {
                            guard tile.type != nil, let colony = data.colonyByTile[tile.id] else { continue }
                            let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
                            let label = Text("\(colony.name ?? "?") · Bevölkerung: \(state.colonyPopulation(colony))")
                                .font(.system(size: max(8, tileW * 0.10), weight: .semibold))
                                .foregroundColor(.white)
                            let resolved = ctx.resolve(label)
                            let measured = resolved.measure(in: CGSize(width: tileW * 2, height: tileH))
                            let rect = CGRect(x: origin.x - measured.width / 2 - 4,
                                              y: origin.y + tileH * 0.3,
                                              width: measured.width + 8, height: measured.height + 4)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.black.opacity(0.8)))
                            ctx.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY))
                        }

                        if state.mapOverlay == .tradeRoutes {
                            let routeColors: [Color] = [.cyan, .orange, .pink, .green, .purple]
                            for (routeIndex, route) in state.localPlayerTradeRoutes.enumerated() {
                                let points = route.stops.compactMap { stop -> CGPoint? in
                                    guard let locationId = stop.locationId,
                                          let tileId = game.tiles[locationId] != nil
                                            ? locationId
                                            : game.colonies[locationId]?.tileId,
                                          let tile = game.tiles[tileId],
                                          data.visibleTileIds.contains(tileId) || !state.showFogOfWar else {
                                        return nil
                                    }
                                    return tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
                                }
                                guard points.count > 1 else { continue }
                                var path = Path()
                                path.move(to: points[0])
                                for point in points.dropFirst() {
                                    path.addLine(to: point)
                                }
                                path.addLine(to: points[0])
                                let color = routeColors[routeIndex % routeColors.count]
                                ctx.stroke(path, with: .color(color), style: StrokeStyle(
                                    lineWidth: max(2, tileW * 0.025),
                                    dash: [8, 5]
                                ))
                                for point in points {
                                    let marker = Path(ellipseIn: CGRect(
                                        x: point.x - 5, y: point.y - 5, width: 10, height: 10
                                    ))
                                    ctx.fill(marker, with: .color(color))
                                    ctx.stroke(marker, with: .color(.black), lineWidth: 1)
                                }
                            }
                        }

                        for selectedUnit in game.units.values.sorted(by: { $0.id < $1.id })
                            where selectedUnit.owner == state.localPlayerId
                                && (selectedUnit.id == state.selectedUnitId || state.mapOverlay == .paths) {
                           if
                           let destinationTileId = selectedUnit.destination,
                           let destinationTile = game.tiles[destinationTileId],
                           let sourceTileId = resolveUnitTileId(selectedUnit, in: game),
                           let sourceTile = game.tiles[sourceTileId] {
                            let sourceOrigin = tileOrigin(x: sourceTile.x, y: sourceTile.y, tileW: tileW, tileH: tileH)
                            var previewPath = Path()
                            previewPath.move(to: sourceOrigin)
                            let route = state.movementPath(for: selectedUnit)
                            for nextTileId in route.dropFirst() {
                                guard let nextTile = game.tiles[nextTileId] else { break }
                                let nextOrigin = tileOrigin(
                                    x: nextTile.x,
                                    y: nextTile.y,
                                    tileW: tileW,
                                    tileH: tileH
                                )
                                previewPath.addLine(to: nextOrigin)
                            }
                            if route.last == destinationTileId {
                                ctx.stroke(
                                    previewPath,
                                    with: .color(.yellow.opacity(0.9)),
                                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                )
                            }

                            let destinationOrigin = tileOrigin(
                                x: destinationTile.x,
                                y: destinationTile.y,
                                tileW: tileW,
                                tileH: tileH
                            )
                            let markerSize = max(10, tileW * 0.15)
                            let markerRect = CGRect(
                                x: destinationOrigin.x - markerSize / 2,
                                y: destinationOrigin.y - markerSize / 2,
                                width: markerSize,
                                height: markerSize
                            )
                            let marker = Path(ellipseIn: markerRect)
                            ctx.stroke(marker, with: .color(.yellow), lineWidth: 2)
                            ctx.draw(Text("Ziel").font(.system(size: max(10, tileW * 0.1), weight: .bold))
                                .foregroundColor(.yellow),
                                     at: CGPoint(x: destinationOrigin.x, y: destinationOrigin.y + markerSize))
                           }
                        }

                        if let cue = state.mapAnimationCue,
                           let sourceTile = game.tiles[cue.sourceTileId],
                           let targetTile = game.tiles[cue.targetTileId] {
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

                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .background(Color(white: 0.08))

                            MapMouseCaptureView(
                                onLeftClick: { location in
                                    let canvasPoint = CGPoint(x: location.x + camera.x,
                                                              y: location.y + camera.y)
                                    handleLeftClick(at: canvasPoint, tileIndex: data.tileIndex, game: game)
                                },
                                onRightClick: { location in
                                    let canvasPoint = CGPoint(x: location.x + camera.x,
                                                              y: location.y + camera.y)
                                    handleRightClick(at: canvasPoint, tileIndex: data.tileIndex)
                                },
                                onDoubleClick: { location in
                                    let point = CGPoint(x: location.x + camera.x, y: location.y + camera.y)
                                    if let tile = data.tileIndex.hitTest(location: point, tileW: tileW, tileH: tileH) {
                                        state.selectMapTile(tile.id, openColony: true)
                                    }
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
                        centerOnSelectedUnit(data: data, game: game)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        camera = MapGeometry.resizedCamera(camera, from: viewportSize, to: newSize,
                                                           canvas: data.canvasSize)
                        viewportSize = newSize
                    }
                    .onChange(of: zoomScale) { _, _ in
                        centerOnSelectedUnit(data: data, game: game)
                    }
                    .onChange(of: state.selectedUnitTileId) { _, _ in
                        // Keep the camera on the active unit as it moves,
                        // but do not jump when the user merely inspects tiles.
                        centerOnSelectedUnit(data: data, game: game)
                    }
                    .onChange(of: state.gameUpdateID) { _, _ in
                        centerOnSelectedUnit(data: data, game: game)
                    }
                    .onChange(of: state.requestedMapScrollTileId) { _, newValue in
                        if let tileId = newValue {
                            centerCamera(on: tileId, data: data, game: game)
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
                Text("Zurücksetzen")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(GameState.MapOverlay.allCases) { overlay in
                    Button {
                        state.mapOverlay = overlay
                    } label: {
                        if state.mapOverlay == overlay {
                            Label(overlay.title, systemImage: "checkmark")
                        } else {
                            Text(overlay.title)
                        }
                    }
                }
            } label: {
                Label(state.mapOverlay.title, systemImage: "square.3.layers.3d")
                    .font(.caption)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.12))
        .help(mapOverlayLegend)
    }

    private var mapOverlayLegend: String {
        switch state.mapOverlay {
        case .none: return "Overlays off"
        case .resources: return "Orange marker: resource"
        case .tradeRoutes: return "Dashed colors: trade routes"
        case .paths: return "Yellow line: selected unit path"
        }
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

    private func handleLeftClick(at location: CGPoint, tileIndex: TileSpatialIndex, game: Game) {
        guard let tappedTile = tileIndex.hitTest(location: location, tileW: tileW, tileH: tileH) else { return }
        state.selectMapTile(tappedTile.id)
    }

    /// Scale an image's size down to fit within `maxSize`, preserving aspect ratio.
    private func drawImprovements(_ tile: Tile, at origin: CGPoint, context: inout GraphicsContext) {
        for improvement in tile.improvements where improvement.turns == 0 {
            if improvement.type == "model.improvement.plow" {
                for offset in [-0.12, 0.0, 0.12] {
                    var furrow = Path()
                    furrow.move(to: CGPoint(x: origin.x - tileW * 0.22, y: origin.y + tileH * offset))
                    furrow.addLine(to: CGPoint(x: origin.x + tileW * 0.1, y: origin.y + tileH * (offset + 0.16)))
                    context.stroke(furrow, with: .color(.brown.opacity(0.7)), lineWidth: max(1, zoomScale))
                }
            }
            let isRoad = improvement.type == "model.improvement.road"
            let isRiver = improvement.type == "model.improvement.river"
            guard isRoad || isRiver, let style = improvement.style else { continue }
            let directions: [CGPoint] = isRoad
                ? [CGPoint(x: 0, y: -0.5), CGPoint(x: 0.25, y: -0.25),
                   CGPoint(x: 0.5, y: 0), CGPoint(x: 0.25, y: 0.25),
                   CGPoint(x: 0, y: 0.5), CGPoint(x: -0.25, y: 0.25),
                   CGPoint(x: -0.5, y: 0), CGPoint(x: -0.25, y: -0.25)]
                : [CGPoint(x: 0.25, y: -0.25), CGPoint(x: 0.25, y: 0.25),
                   CGPoint(x: -0.25, y: 0.25), CGPoint(x: -0.25, y: -0.25)]
            var route = Path()
            for (index, connection) in style.enumerated() where connection != "0" && index < directions.count {
                route.move(to: origin)
                route.addLine(to: CGPoint(x: origin.x + tileW * directions[index].x,
                                         y: origin.y + tileH * directions[index].y))
            }
            context.stroke(route, with: .color(isRiver ? .cyan.opacity(0.8) : .brown),
                           style: StrokeStyle(lineWidth: max(1.5, zoomScale * (isRiver ? 2 : 1)), lineCap: .round))
        }
    }

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
    private func centerCamera(on tileId: String, data: RenderData, game: Game) {
        guard viewportSize.width > 0,
              let tile = game.tiles[tileId] else { return }
        let origin = tileOrigin(x: tile.x, y: tile.y, tileW: tileW, tileH: tileH)
        camera = clampCamera(
            CGPoint(x: origin.x - viewportSize.width / 2,
                    y: origin.y - viewportSize.height / 2),
            canvas: data.canvasSize
        )
    }

    /// Keep the camera on the active unit.
    private func centerOnSelectedUnit(data: RenderData, game: Game) {
        guard let tileId = state.selectedUnitTileId else { return }
        centerCamera(on: tileId, data: data, game: game)
    }

    private func handleRightClick(at location: CGPoint, tileIndex: TileSpatialIndex) {
        guard let tappedTile = tileIndex.hitTest(location: location, tileW: tileW, tileH: tileH) else { return }

        state.rightClickMapTile(tappedTile.id, showMenu: NSEvent.modifierFlags.contains(.option))
    }
}
