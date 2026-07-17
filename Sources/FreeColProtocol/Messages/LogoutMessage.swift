import Foundation

public struct LogoutMessage: FreeColMessage {
    public static let tag = "logout"

    public let reason: String?
    public let player: String?

    public init(
        reason: String? = nil,
        player: String? = nil
    ) {
        self.reason = reason
        self.player = player
    }

    public init(attributes: Attributes, children: Children) throws {
        self.reason = attributes["reason"]
        self.player = attributes["player"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = reason { attrs["reason"] = v }
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
