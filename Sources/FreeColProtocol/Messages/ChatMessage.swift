import Foundation

public struct ChatMessage: FreeColMessage {
    public static let tag = "chat"

    public let color: String?
    public let `private`: String?
    public let message: String?
    public let sender: String?

    public init(
        color: String? = nil,
        `private`: String? = nil,
        message: String? = nil,
        sender: String? = nil
    ) {
        self.color = color
        self.`private` = `private`
        self.message = message
        self.sender = sender
    }

    public init(attributes: Attributes, children: Children) throws {
        self.color = attributes["color"]
        self.`private` = attributes["private"]
        self.message = attributes["message"]
        self.sender = attributes["sender"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = color { attrs["color"] = v }
        if let v = `private` { attrs["private"] = v }
        if let v = message { attrs["message"] = v }
        if let v = sender { attrs["sender"] = v }
        return (attrs, [])
    }
}
