import Foundation
import FreeColGame

struct TileSpatialIndex {
  private let sortedTiles: [Tile]

  init(tiles: [Tile]) {
    sortedTiles = tiles.sorted {
      $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
    }
  }

  init(sortedTiles: [Tile]) {
    self.sortedTiles = sortedTiles
  }

  func visibleTiles(in rect: CGRect, tileW: Double, tileH: Double) -> [Tile] {
    guard tileW > 0, tileH > 0,
      rect.minX.isFinite, rect.maxX.isFinite,
      rect.minY.isFinite, rect.maxY.isFinite
    else {
      return []
    }

    let colW = tileW / 2
    let rowH = tileH / 2
    let minY = Int(ceil((rect.minY - rowH) / rowH - 1))
    let maxY = Int(floor((rect.maxY + rowH) / rowH - 1))
    let minX = rect.minX - colW
    let maxX = rect.maxX + colW
    var result: [Tile] = []

    guard minY <= maxY else { return result }
    for y in minY...maxY {
      let stagger = y.isMultiple(of: 2) ? 0.0 : 0.5
      let firstX = Int(ceil(minX / tileW - 0.5 - stagger))
      let lastX = Int(floor(maxX / tileW - 0.5 - stagger))
      guard firstX <= lastX else { continue }

      var index = lowerBound(y: y, x: firstX)
      while index < sortedTiles.count,
        sortedTiles[index].y == y,
        sortedTiles[index].x <= lastX {
        result.append(sortedTiles[index])
        index += 1
      }
    }
    return result
  }

  func hitTest(location: CGPoint, tileW: Double, tileH: Double) -> Tile? {
    guard tileW > 0, tileH > 0,
      location.x.isFinite, location.y.isFinite
    else {
      return nil
    }

    let colW = tileW / 2
    let rowH = tileH / 2
    let minY = Int(ceil((location.y - rowH) / rowH - 1))
    let maxY = Int(floor((location.y + rowH) / rowH - 1))
    var bestTile: Tile?
    var bestScore = Double.greatestFiniteMagnitude

    guard minY <= maxY else { return nil }
    for y in minY...maxY {
      let stagger = y.isMultiple(of: 2) ? 0.0 : 0.5
      let firstX = Int(ceil((location.x - colW) / tileW - 0.5 - stagger))
      let lastX = Int(floor((location.x + colW) / tileW - 0.5 - stagger))
      guard firstX <= lastX else { continue }

      var index = lowerBound(y: y, x: firstX)
      while index < sortedTiles.count,
        sortedTiles[index].y == y,
        sortedTiles[index].x <= lastX {
        let tile = sortedTiles[index]
        let origin = MapGeometry.origin(x: tile.x, y: y, tileW: tileW, tileH: tileH)
        let score =
          abs(location.x - origin.x) / colW
          + abs(location.y - origin.y) / rowH
        if score <= 1, score <= bestScore {
          bestScore = score
          bestTile = tile
        }
        index += 1
      }
    }
    return bestTile
  }

  private func lowerBound(y: Int, x: Int) -> Int {
    var lower = 0
    var upper = sortedTiles.count
    while lower < upper {
      let middle = (lower + upper) / 2
      let tile = sortedTiles[middle]
      if tile.y < y || (tile.y == y && tile.x < x) {
        lower = middle + 1
      } else {
        upper = middle
      }
    }
    return lower
  }
}
