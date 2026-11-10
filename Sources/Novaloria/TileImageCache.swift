import AppKit
import FreeColGame

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

    /// FreeCol's river sprites are keyed by four base-three connection digits.
    /// The style digits are ordered NE, SE, SW, NW, least-significant first.
    func riverImage(forStyle style: String?) -> NSImage? {
        guard let style, style.count == 4 else { return nil }
        var imageIndex = 0
        var placeValue = 1
        for character in style {
            guard let digit = character.wholeNumberValue, (0...2).contains(digit) else { return nil }
            imageIndex += digit * placeValue
            placeValue *= 3
        }
        return loadImage(named: "river\(imageIndex)", folder: "rivers")
    }

    func improvementImage(forType improvementType: String?) -> NSImage? {
        guard let improvementType else { return nil }
        switch improvementType {
        case "model.improvement.plow":
            return loadImage(named: "plowed", folder: "terrain")
        default:
            let name = improvementType.components(separatedBy: ".").last ?? improvementType
            return loadImage(named: name, folder: "terrain")
        }
    }

    func improvementBonusImage(forType improvementType: String?) -> NSImage? {
        switch improvementType {
        case "model.improvement.fishBonusLand", "model.improvement.fishBonusRiver":
            return resourceImage(for: "model.resource.fish")
        default:
            return nil
        }
    }

    /// The original client's high-seas marker is a cloud layer above the terrain and units.
    func highSeasExitImage(for tile: Tile) -> NSImage? {
        guard tile.type != nil, tile.moveToEurope else { return nil }
        return cloudImage(forX: tile.x, y: tile.y)
    }

    func lostCityRumourImage(for tile: Tile) -> NSImage? {
        guard tile.type != nil, tile.hasLostCityRumour else { return nil }
        return loadImage(named: "lostCityRumour", folder: "terrain")
    }

    func resourceImage(for type: String?) -> NSImage? {
        guard let type, type.hasPrefix("model.resource.") else { return nil }
        let name = type.components(separatedBy: ".").last ?? type
        return loadImage(named: "resource_\(name)", folder: "terrain")
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

    func unitImage(forUnitType unitType: String?, role: String? = nil) -> NSImage? {
        guard let unitType else { return nil }
        if unitType == "model.unit.treasureTrain",
           let treasureTrainImage = loadImage(named: "model.unit.treasureTrain", folder: "colopedia") {
            return treasureTrainImage
        }
        let roleSpecificImageName: String?
        switch (unitType, role ?? "") {
        case ("model.unit.hardyPioneer", "model.role.pioneer"):
            roleSpecificImageName = "hardyPioneer.pioneer"
        case ("model.unit.seasonedScout", "model.role.scout"):
            roleSpecificImageName = "seasonedScout.scout"
        case ("model.unit.veteranSoldier", "model.role.dragoon"):
            roleSpecificImageName = "veteranSoldier.dragoon"
        case ("model.unit.colonialRegular", "model.role.dragoon"):
            roleSpecificImageName = "colonialRegular.dragoon"
        default:
            roleSpecificImageName = nil
        }
        if let roleSpecificImageName,
           let roleImage = loadImage(named: roleSpecificImageName, folder: "units") {
            return roleImage
        }
        let roleImageName: String?
        switch role {
        case "model.role.pioneer": roleImageName = "pioneer"
        case "model.role.scout": roleImageName = "scout"
        case "model.role.soldier": roleImageName = "soldier"
        case "model.role.dragoon": roleImageName = "dragoon"
        default: roleImageName = nil
        }
        if let roleImageName, let roleImage = loadImage(named: roleImageName, folder: "units") {
            return roleImage
        }
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

    func goodsImage(for goodsType: String) -> NSImage? {
        guard let entry = ColopediaCatalog.classicEntries.first(where: { $0.id == goodsType }) else { return nil }
        return colopediaImage(for: entry)
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

    func loadImage(named name: String, folder: String) -> NSImage? {
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
