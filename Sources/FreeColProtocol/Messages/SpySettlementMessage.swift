import Foundation

public struct SpySettlementMessage: FreeColMessage {
    public static let tag = "spySettlement"

    public let unit: String?
    public let settlement: String?
    public let children: [ParsedMessage]

    public init(
        unit: String? = nil,
        settlement: String? = nil
    ) {
        self.unit = unit
        self.settlement = settlement
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.settlement = attributes["settlement"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = settlement { attrs["settlement"] = v }
        return (attrs, [])
    }
}
