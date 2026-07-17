import Foundation

public struct ChatMessage: FreeColMessage {
    public static let tag = "chat"

    public let message: String?
    public let color: String?
    public let `private`: String?
    public let sender: String?

    public init(
        message: String? = nil,
        color: String? = nil,
        `private`: String? = nil,
        sender: String? = nil
    ) {
        self.message = message
        self.color = color
        self.`private` = `private`
        self.sender = sender
    }

    public init(attributes: Attributes, children: Children) throws {
        self.message = attributes["message"]
        self.color = attributes["color"]
        self.`private` = attributes["private"]
        self.sender = attributes["sender"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = message { attrs["message"] = v }
        if let v = color { attrs["color"] = v }
        if let v = `private` { attrs["private"] = v }
        if let v = sender { attrs["sender"] = v }
        return (attrs, [])
    }
}
