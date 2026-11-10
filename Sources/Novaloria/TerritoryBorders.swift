import SwiftUI
import FreeColGame

struct TerritoryBorders {
    private struct Vertex: Hashable {
        let x: Int
        let y: Int

        var point: CGPoint { CGPoint(x: x, y: y) }
    }

    let contoursByOwner: [String: [[CGPoint]]]

    init(tiles: [Tile]) {
        var owners: [Vertex: String] = [:]
        for tile in tiles where tile.type != nil {
            owners[Vertex(x: tile.x, y: tile.y)] = tile.owner
        }
        var edgesByOwner: [String: [Vertex: Set<Vertex>]] = [:]
        for tile in tiles where tile.type != nil {
            guard let owner = tile.owner else { continue }
            let stagger = tile.y.isMultiple(of: 2) ? 0 : 1
            let x = tile.x * 2 + stagger + 1
            let vertices = [
                Vertex(x: x, y: tile.y),
                Vertex(x: x + 1, y: tile.y + 1),
                Vertex(x: x, y: tile.y + 2),
                Vertex(x: x - 1, y: tile.y + 1),
            ]
            let neighbors = [
                Vertex(x: tile.x + stagger, y: tile.y - 1),
                Vertex(x: tile.x + stagger, y: tile.y + 1),
                Vertex(x: tile.x + stagger - 1, y: tile.y + 1),
                Vertex(x: tile.x + stagger - 1, y: tile.y - 1),
            ]
            for edge in 0..<4 where owners[neighbors[edge]] != owner {
                edgesByOwner[owner, default: [:]][vertices[edge], default: []]
                    .insert(vertices[(edge + 1) % 4])
            }
        }

        var contours: [String: [[CGPoint]]] = [:]
        for (owner, var edges) in edgesByOwner {
            while let start = edges.keys.first {
                var previous = start
                var current = start
                var contour: [CGPoint] = []
                repeat {
                    contour.append(current.point)
                    // Keep corner-touching territories separate by taking the
                    // clockwise turn when more than one boundary meets here.
                    let next = edges[current]!.max { lhs, rhs in
                        let dx = current.x - previous.x
                        let dy = current.y - previous.y
                        return dx * (lhs.y - current.y) - dy * (lhs.x - current.x)
                            < dx * (rhs.y - current.y) - dy * (rhs.x - current.x)
                    }!
                    edges[current]!.remove(next)
                    if edges[current]!.isEmpty { edges.removeValue(forKey: current) }
                    previous = current
                    current = next
                } while current != start
                contours[owner, default: []].append(contour)
            }
        }
        contoursByOwner = contours
    }

    func path(for owner: String, tileW: Double, tileH: Double) -> Path {
        var path = Path()
        for contour in contoursByOwner[owner] ?? [] {
            let points = contour.map { CGPoint(x: $0.x * tileW / 2, y: $0.y * tileH / 2) }
            func inset(_ vertex: CGPoint, toward neighbor: CGPoint) -> CGPoint {
                CGPoint(x: vertex.x + (neighbor.x - vertex.x) * 0.2,
                        y: vertex.y + (neighbor.y - vertex.y) * 0.2)
            }
            path.move(to: inset(points[0], toward: points[points.count - 1]))
            for index in points.indices {
                let vertex = points[index]
                let next = points[(index + 1) % points.count]
                path.addQuadCurve(to: inset(vertex, toward: next), control: vertex)
                path.addLine(to: inset(next, toward: vertex))
            }
            path.closeSubpath()
        }
        return path
    }
}
