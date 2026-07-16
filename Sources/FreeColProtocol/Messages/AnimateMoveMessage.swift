import Foundation

public struct AnimateMoveMessage: FreeColMessage {
    public static let tag = "animateMove"

    public let oldTile: String?
    public let unit: String?
    public let newTile: String?
    public let children: [ParsedMessage]

    public init(
        oldTile: String? = nil,
        unit: String? = nil,
        newTile: String? = nil
    ) {
        self.oldTile = oldTile
        self.unit = unit
        self.newTile = newTile
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.oldTile = attributes["oldTile"]
        self.unit = attributes["unit"]
        self.newTile = attributes["newTile"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = oldTile { attrs["oldTile"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = newTile { attrs["newTile"] = v }
        return (attrs, [])
    }
}
