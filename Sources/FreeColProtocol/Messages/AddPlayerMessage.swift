import Foundation

public struct AddPlayerMessage: FreeColMessage {
    public static let tag = "addPlayer"

    public let children: [ParsedMessage]

    public init(

    ) {
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        return (attrs, [])
    }
}
