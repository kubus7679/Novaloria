import Foundation

public struct SetAIMessage: FreeColMessage {
    public static let tag = "setAI"

    public let player: String?
    public let ai: String?

    public init(
        player: String? = nil,
        ai: String? = nil
    ) {
        self.player = player
        self.ai = ai
    }

    public init(attributes: Attributes, children: Children) throws {
        self.player = attributes["player"]
        self.ai = attributes["ai"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = player { attrs["player"] = v }
        if let v = ai { attrs["ai"] = v }
        return (attrs, [])
    }
}
