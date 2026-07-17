import Foundation

public struct FirstContactMessage: FreeColMessage {
    public static let tag = "firstContact"

    public let result: String?
    public let other: String?
    public let camps: String?
    public let tile: String?
    public let player: String?

    public init(
        result: String? = nil,
        other: String? = nil,
        camps: String? = nil,
        tile: String? = nil,
        player: String? = nil
    ) {
        self.result = result
        self.other = other
        self.camps = camps
        self.tile = tile
        self.player = player
    }

    public init(attributes: Attributes, children: Children) throws {
        self.result = attributes["result"]
        self.other = attributes["other"]
        self.camps = attributes["camps"]
        self.tile = attributes["tile"]
        self.player = attributes["player"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = result { attrs["result"] = v }
        if let v = other { attrs["other"] = v }
        if let v = camps { attrs["camps"] = v }
        if let v = tile { attrs["tile"] = v }
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
