import Foundation

public struct SetNationTypeMessage: FreeColMessage {
    public static let tag = "setNationType"

    public let value: String?
    public let player: String?

    public init(
        value: String? = nil,
        player: String? = nil
    ) {
        self.value = value
        self.player = player
    }

    public init(attributes: Attributes, children: Children) throws {
        self.value = attributes["value"]
        self.player = attributes["player"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = value { attrs["value"] = v }
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
