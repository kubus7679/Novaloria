import Foundation

public struct SetAIMessage: FreeColMessage {
    public static let tag = "setAI"

    public let ai: String?
    public let player: String?

    public init(
        ai: String? = nil,
        player: String? = nil
    ) {
        self.ai = ai
        self.player = player
    }

    public init(attributes: Attributes, children: Children) throws {
        self.ai = attributes["ai"]
        self.player = attributes["player"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = ai { attrs["ai"] = v }
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
