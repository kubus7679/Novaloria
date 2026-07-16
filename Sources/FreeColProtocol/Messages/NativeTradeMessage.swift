import Foundation

public struct NativeTradeMessage: FreeColMessage {
    public static let tag = "nativeTrade"

    public let action: String?
    public let children: [ParsedMessage]

    public init(
        action: String? = nil
    ) {
        self.action = action
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.action = attributes["action"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = action { attrs["action"] = v }
        return (attrs, [])
    }
}
