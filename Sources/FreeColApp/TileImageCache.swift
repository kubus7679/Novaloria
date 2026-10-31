import AppKit

/// Loads and caches NSImages from the app bundle's Resources folders.
final class TileImageCache {
    static let shared = TileImageCache()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func terrainImage(forType tileType: String?) -> NSImage? {
        guard let tileType else { return nil }
        let name = tileType.components(separatedBy: ".").last ?? tileType
        return loadImage(named: "\(name)_base", folder: "terrain")
            ?? loadImage(named: name, folder: "terrain")
    }

    func terrainOverlay(forType tileType: String?) -> NSImage? {
        guard let tileType else { return nil }
        let name = tileType.components(separatedBy: ".").last ?? tileType
        return loadImage(named: "\(name)_overlay", folder: "terrain")
    }

    func beachImages(style: Int) -> [NSImage] {
        guard style > 0 else { return [] }
        return [("edge", (style >> 4) & 15), ("corner", style & 15)].compactMap { kind, index in
            guard index > 0 else { return nil }
            return loadImage(named: "beach_\(kind)\(index)", folder: "terrain")
        }
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

    func colopediaImage(for entry: ColopediaEntry) -> NSImage? {
        if entry.category == .units, let image = unitImage(forUnitType: entry.id) { return image }
        if entry.category == .terrain {
            return terrainOverlay(forType: entry.id) ?? terrainImage(forType: entry.id)
        }
        guard let filename = entry.icon else { return nil }
        let key = "colopedia/\(filename)"
        if let image = cache[key] { return image }
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "colopedia"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[key] = image
        return image
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
