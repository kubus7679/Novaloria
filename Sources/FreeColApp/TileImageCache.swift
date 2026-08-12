import AppKit

/// Loads and caches NSImages from the app bundle's Resources folders.
final class TileImageCache {
    static let shared = TileImageCache()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func terrainImage(forType tileType: String?) -> NSImage? {
        guard let tileType else { return nil }
        // "model.tile.borealForest" → "borealForest"
        let name = tileType.components(separatedBy: ".").last ?? tileType
        return loadImage(named: name, folder: "terrain")
    }

    /// Returns one of the 4 cloud textures for fog-of-war.
    /// The variant is chosen deterministically from tile coordinates
    /// to mimic the Java client's staggered cloud pattern.
    func cloudImage(forX x: Int, y: Int) -> NSImage? {
        let variant = (x * 7 + y * 13) % 4
        return loadImage(named: "clouds\(variant)", folder: "terrain")
    }

    func unitImage(forUnitType unitType: String?) -> NSImage? {
        guard let unitType else { return nil }
        // "model.unit.freeColonist" → "freeColonist"
        let name = unitType.components(separatedBy: ".").last ?? unitType
        return loadImage(named: name, folder: "units")
    }

    func settlementImage(for settlement: SettlementKind) -> NSImage? {
        return loadImage(named: settlement.imageName, folder: "settlements")
    }

    /// Order-button icons from the Java client (wait/sentry/fortify/build/disband/done).
    func orderButtonImage(named name: String) -> NSImage? {
        return loadImage(named: name, folder: "order-buttons")
    }

    // MARK: - Private

    private func loadImage(named name: String, folder: String) -> NSImage? {
        let key = "\(folder)/\(name)"
        if let cached = cache[key] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: folder),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache[key] = image
        return image
    }
}

enum SettlementKind {
    case colony(size: Int)          // size: 1=small, 2=medium, 3=large
    case nativeCamp
    case nativeVillage
    case aztecCity
    case incaCity

    var imageName: String {
        switch self {
        case .colony(let size):
            switch size {
            case 1: return "colony_small"
            case 2: return "colony_medium"
            default: return "colony_large"
            }
        case .nativeCamp:    return "indian_camp"
        case .nativeVillage: return "indian_village"
        case .aztecCity:     return "aztec_city"
        case .incaCity:      return "inca_city"
        }
    }
}
