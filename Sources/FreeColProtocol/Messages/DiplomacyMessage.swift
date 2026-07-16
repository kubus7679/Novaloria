import Foundation

public struct DiplomacyMessage: FreeColMessage {
    public static let tag = "diplomacy"

    public let otherId: String?
    public let ourId: String?
    public let children: [ParsedMessage]

    public init(
        otherId: String? = nil,
        ourId: String? = nil
    ) {
        self.otherId = otherId
        self.ourId = ourId
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.otherId = attributes["otherId"]
        self.ourId = attributes["ourId"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = otherId { attrs["otherId"] = v }
        if let v = ourId { attrs["ourId"] = v }
        return (attrs, [])
    }
}
