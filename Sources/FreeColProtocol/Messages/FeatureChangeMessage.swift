import Foundation

public struct FeatureChangeMessage: FreeColMessage {
    public static let tag = "featureChange"

    public let add: String?
    public let children: [ParsedMessage]

    public init(
        add: String? = nil
    ) {
        self.add = add
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.add = attributes["add"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = add { attrs["add"] = v }
        return (attrs, [])
    }
}
