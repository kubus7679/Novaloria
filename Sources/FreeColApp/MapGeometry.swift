import Foundation

enum MapGeometry {
    static func origin(x: Int, y: Int, tileW: Double, tileH: Double) -> CGPoint {
        let stagger = y.isMultiple(of: 2) ? 0.0 : tileW / 2
        return CGPoint(
            x: Double(x) * tileW + stagger + tileW / 2,
            y: Double(y + 1) * tileH / 2
        )
    }

    static func canvasSize(maxX: Int, maxY: Int, tileW: Double, tileH: Double) -> CGSize {
        CGSize(width: Double(maxX + 2) * tileW, height: Double(maxY + 2) * tileH / 2)
    }

    static func resizedCamera(_ camera: CGPoint, from oldSize: CGSize, to newSize: CGSize,
                              canvas: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, camera.x + (oldSize.width - newSize.width) / 2), max(0, canvas.width - newSize.width)),
            y: min(max(0, camera.y + (oldSize.height - newSize.height) / 2), max(0, canvas.height - newSize.height))
        )
    }
}
