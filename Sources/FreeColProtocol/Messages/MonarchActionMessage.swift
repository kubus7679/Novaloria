import Foundation

public struct MonarchActionMessage: FreeColMessage {
    public static let tag = "monarchAction"

    public let monarch: String?
    public let tax: String?
    public let result: String?
    public let action: String?
    public let children: [ParsedMessage]

    public init(
        monarch: String? = nil,
        tax: String? = nil,
        result: String? = nil,
        action: String? = nil
    ) {
        self.monarch = monarch
        self.tax = tax
        self.result = result
        self.action = action
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.monarch = attributes["monarch"]
        self.tax = attributes["tax"]
        self.result = attributes["result"]
        self.action = attributes["action"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = monarch { attrs["monarch"] = v }
        if let v = tax { attrs["tax"] = v }
        if let v = result { attrs["result"] = v }
        if let v = action { attrs["action"] = v }
        return (attrs, [])
    }
}
