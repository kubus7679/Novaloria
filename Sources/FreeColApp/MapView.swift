import SwiftUI
import FreeColGame

private let hexSize: Double = 24
private let w = hexSize * 1.5
private let h = hexSize * sqrt(3)
private let colW = w
private let rowH = h * 0.75

private func hexCenter(col: Int, row: Int) -> CGPoint {
    let x = Double(col) * colW + w * 0.5
    let y = Double(row) * rowH + (Double(col.isMultiple(of: 2) ? 0 : 1)) * h * 0.5 + h * 0.25
    return CGPoint(x: x, y: y)
}

private func hexVertices(center: CGPoint) -> [CGPoint] {
    let s = hexSize
    let a = s * 0.5
    let b = s * sqrt(3) * 0.5
    return [
        CGPoint(x: center.x - s, y: center.y),
        CGPoint(x: center.x - a, y: center.y - b),
        CGPoint(x: center.x + a, y: center.y - b),
        CGPoint(x: center.x + s, y: center.y),
        CGPoint(x: center.x + a, y: center.y + b),
        CGPoint(x: center.x - a, y: center.y + b),
    ]
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

struct MapView: View {
    @Environment(GameState.self) private var state

    var body: some View {
        if let game = state.game, let _ = game.map {
            let tiles = game.tiles.values.map { $0 }
            let maxCol = tiles.map(\.x).max() ?? 0
            let maxRow = tiles.map(\.y).max() ?? 0
            let canvasW = colW * Double(maxCol + 2)
            let canvasH = rowH * Double(maxRow + 2) + h * 0.5

            ScrollView([.horizontal, .vertical]) {
                Canvas { ctx, size in
                    for tile in tiles {
                        let center = hexCenter(col: tile.x, row: tile.y)
                        let verts = hexVertices(center: center)
                        let color = colorForTile(tile.type)
                        var path = Path()
                        path.addLines(verts)
                        path.closeSubpath()
                        ctx.fill(path, with: .color(color))
                        ctx.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 0.5)

                        // Draw colony/indian settlement marker
                        if tile.settlement != nil {
                            let marker = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                            ctx.fill(marker, with: .color(.black))
                            ctx.stroke(marker, with: .color(.white), lineWidth: 1)
                        }

                        // Draw units on this tile
                        let unitsOnTile = game.units.values.filter { $0.location == tile.id }
                        for (i, _) in unitsOnTile.enumerated() {
                            let ux = center.x - 6 + Double(i) * 6
                            let uy = center.y + 6
                            let dot = Path(ellipseIn: CGRect(x: ux - 2, y: uy - 2, width: 4, height: 4))
                            ctx.fill(dot, with: .color(.white))
                            ctx.stroke(dot, with: .color(.black), lineWidth: 0.5)
                        }
                    }
                }
                .frame(width: canvasW, height: canvasH)
            }
        } else {
            Text("No map loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
