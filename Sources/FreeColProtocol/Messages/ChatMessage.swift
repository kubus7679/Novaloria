import Foundation

public struct ChatMessage: FreeColMessage {
    public static let tag = "chat"

    public let sender: String?
    public let message: String?
    public let `private`: String?
    public let color: String?

    public init(
        sender: String? = nil,
        message: String? = nil,
        `private`: String? = nil,
        color: String? = nil
    ) {
        self.sender = sender
        self.message = message
        self.`private` = `private`
        self.color = color
    }

    public init(attributes: Attributes, children: Children) throws {
        self.sender = attributes["sender"]
        self.message = attributes["message"]
        self.`private` = attributes["private"]
        self.color = attributes["color"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = sender { attrs["sender"] = v }
        if let v = message { attrs["message"] = v }
        if let v = `private` { attrs["private"] = v }
        if let v = color { attrs["color"] = v }
        return (attrs, [])
    }
}
