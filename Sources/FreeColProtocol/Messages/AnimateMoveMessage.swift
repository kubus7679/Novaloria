import Foundation

public struct AnimateMoveMessage: FreeColMessage {
    public static let tag = "animateMove"

    public let oldTile: String?
    public let newTile: String?
    public let unit: String?
    public let children: [ParsedMessage]

    public init(
        oldTile: String? = nil,
        newTile: String? = nil,
        unit: String? = nil
    ) {
        self.oldTile = oldTile
        self.newTile = newTile
        self.unit = unit
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.oldTile = attributes["oldTile"]
        self.newTile = attributes["newTile"]
        self.unit = attributes["unit"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = oldTile { attrs["oldTile"] = v }
        if let v = newTile { attrs["newTile"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
