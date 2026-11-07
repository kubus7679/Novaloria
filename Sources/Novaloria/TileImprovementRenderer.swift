import SwiftUI
import FreeColGame

/// Shared tile-item rendering for the world map and the colony work-area map.
enum TileImprovementRenderer {
    private enum Direction: Int, CaseIterable {
        case north, northEast, east, southEast, south, southWest, west, northWest

        func point(in size: CGSize) -> CGPoint {
            let points: [(CGFloat, CGFloat)] = [
                (0.5, 0), (0.75, 0.25), (1, 0.5), (0.75, 0.75),
                (0.5, 1), (0.25, 0.75), (0, 0.5), (0.25, 0.25),
            ]
            let point = points[rawValue]
            return CGPoint(x: size.width * point.0, y: size.height * point.1)
        }
    }

    static func draw(_ improvements: [TileImprovement], in context: inout GraphicsContext,
                     rect: CGRect, zoomScale: CGFloat = 1) {
        let completed = improvements.filter { $0.turns == 0 }

        // The original FreeCol river art is a transparent, full-tile sprite
        // selected by the improvement's four directional connection digits.
        for improvement in completed where improvement.type == "model.improvement.river" {
            guard let image = TileImageCache.shared.riverImage(forStyle: improvement.style) else { continue }
            context.draw(Image(nsImage: image), in: rect)
        }

        for improvement in completed {
            guard let type = improvement.type else { continue }
            if type == "model.improvement.road" {
                drawRoad(style: improvement.style, in: &context, rect: rect, zoomScale: zoomScale)
            } else if type != "model.improvement.river",
                      let image = TileImageCache.shared.improvementImage(forType: type) {
                context.draw(Image(nsImage: image), in: rect)
            } else if type != "model.improvement.river" {
                drawImprovementMarker(type: type, in: &context, rect: rect)
            }
        }
    }

    private static func drawRoad(style: String?, in context: inout GraphicsContext,
                                 rect: CGRect, zoomScale: CGFloat) {
        let size = rect.size
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let directions = Array(Direction.allCases)
        let exits = (style?.count == 8 ? Array(style!) : []).enumerated().compactMap { index, char in
            char == "0" ? nil : directions[index]
        }

        var road = Path()
        if exits.isEmpty {
            // FreeCol displays a completed isolated road as a small crossing.
            road.move(to: CGPoint(x: rect.minX + size.width * 0.35, y: rect.minY + size.height * 0.35))
            road.addLine(to: CGPoint(x: rect.minX + size.width * 0.65, y: rect.minY + size.height * 0.65))
            road.move(to: CGPoint(x: rect.minX + size.width * 0.35, y: rect.minY + size.height * 0.65))
            road.addLine(to: CGPoint(x: rect.minX + size.width * 0.65, y: rect.minY + size.height * 0.35))
        } else if exits.count == 2 {
            let first = exits[0].point(in: size)
            let second = exits[1].point(in: size)
            road.move(to: CGPoint(x: rect.minX + first.x, y: rect.minY + first.y))
            road.addQuadCurve(to: CGPoint(x: rect.minX + second.x, y: rect.minY + second.y), control: center)
        } else {
            for direction in exits {
                road.move(to: center)
                let point = direction.point(in: size)
                road.addLine(to: CGPoint(x: rect.minX + point.x, y: rect.minY + point.y))
            }
        }
        context.stroke(road, with: .color(Color(red: 128 / 255, green: 64 / 255, blue: 0)),
                       style: StrokeStyle(lineWidth: max(1.25, zoomScale * 2), lineCap: .round))
    }

    private static func drawImprovementMarker(type: String, in context: inout GraphicsContext,
                                               rect: CGRect) {
        if let image = TileImageCache.shared.improvementBonusImage(forType: type) {
            let width = rect.width * 0.25
            let height = width * image.size.height / max(1, image.size.width)
            context.draw(Image(nsImage: image), in: CGRect(
                x: rect.midX - width / 2, y: rect.midY - height / 2,
                width: width, height: height
            ))
            return
        }
        let name = type.components(separatedBy: ".").last?.lowercased() ?? type.lowercased()
        let symbol: String
        if name.contains("mine") || name.contains("quarry") {
            let label = context.resolve(Text("⛏")
                .font(.system(size: rect.width * 0.32, weight: .bold))
                .foregroundColor(.white))
            context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
            return
        } else if name.contains("forest") || name.contains("plant") {
            symbol = "tree.fill"
        } else {
            symbol = "hammer.fill"
        }
        let image = Image(systemName: symbol)
        let badgeRect = CGRect(x: rect.midX - rect.width * 0.15,
                               y: rect.midY - rect.height * 0.3,
                               width: rect.width * 0.3, height: rect.height * 0.6)
        context.draw(image, in: badgeRect)
    }
}
