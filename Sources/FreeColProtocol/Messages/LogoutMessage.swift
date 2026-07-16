import Foundation

public struct LogoutMessage: FreeColMessage {
    public static let tag = "logout"

    public let player: String?
    public let reason: String?

    public init(
        player: String? = nil,
        reason: String? = nil
    ) {
        self.player = player
        self.reason = reason
    }

    public init(attributes: Attributes, children: Children) throws {
        self.player = attributes["player"]
        self.reason = attributes["reason"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = player { attrs["player"] = v }
        if let v = reason { attrs["reason"] = v }
        return (attrs, [])
    }
}
