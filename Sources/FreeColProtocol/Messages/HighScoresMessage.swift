import Foundation

public struct HighScoresMessage: FreeColMessage {
    public static let tag = "highScores"

    public let key: String?
    public let children: [ParsedMessage]

    public init(
        key: String? = nil
    ) {
        self.key = key
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.key = attributes["key"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = key { attrs["key"] = v }
        return (attrs, [])
    }
}
