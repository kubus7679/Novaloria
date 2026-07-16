import Foundation

public struct SpySettlementMessage: FreeColMessage {
    public static let tag = "spySettlement"

    public let settlement: String?
    public let unit: String?
    public let children: [ParsedMessage]

    public init(
        settlement: String? = nil,
        unit: String? = nil
    ) {
        self.settlement = settlement
        self.unit = unit
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.settlement = attributes["settlement"]
        self.unit = attributes["unit"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = settlement { attrs["settlement"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
