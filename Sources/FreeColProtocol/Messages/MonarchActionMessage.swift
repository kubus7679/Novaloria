import Foundation

public struct MonarchActionMessage: FreeColMessage {
    public static let tag = "monarchAction"

    public let result: String?
    public let monarch: String?
    public let action: String?
    public let tax: String?
    public let children: [ParsedMessage]

    public init(
        result: String? = nil,
        monarch: String? = nil,
        action: String? = nil,
        tax: String? = nil
    ) {
        self.result = result
        self.monarch = monarch
        self.action = action
        self.tax = tax
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.result = attributes["result"]
        self.monarch = attributes["monarch"]
        self.action = attributes["action"]
        self.tax = attributes["tax"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = result { attrs["result"] = v }
        if let v = monarch { attrs["monarch"] = v }
        if let v = action { attrs["action"] = v }
        if let v = tax { attrs["tax"] = v }
        return (attrs, [])
    }
}
