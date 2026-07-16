import Foundation

public struct NationSummaryMessage: FreeColMessage {
    public static let tag = "nationSummary"

    public let player: String?
    public let children: [ParsedMessage]

    public init(
        player: String? = nil
    ) {
        self.player = player
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.player = attributes["player"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
