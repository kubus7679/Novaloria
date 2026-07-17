import Foundation

public struct DiplomacyMessage: FreeColMessage {
    public static let tag = "diplomacy"

    public let ourId: String?
    public let otherId: String?
    public let children: [ParsedMessage]

    public init(
        ourId: String? = nil,
        otherId: String? = nil
    ) {
        self.ourId = ourId
        self.otherId = otherId
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.ourId = attributes["ourId"]
        self.otherId = attributes["otherId"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = ourId { attrs["ourId"] = v }
        if let v = otherId { attrs["otherId"] = v }
        return (attrs, [])
    }
}
