import Foundation

public struct ErrorMessage: FreeColMessage {
    public static let tag = "error"

    public let message: String?
    public let children: [ParsedMessage]

    public init(
        message: String? = nil
    ) {
        self.message = message
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.message = attributes["message"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = message { attrs["message"] = v }
        return (attrs, [])
    }
}
