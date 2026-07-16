import Foundation

public struct FirstContactMessage: FreeColMessage {
    public static let tag = "firstContact"

    public let tile: String?
    public let player: String?
    public let other: String?
    public let camps: String?
    public let result: String?

    public init(
        tile: String? = nil,
        player: String? = nil,
        other: String? = nil,
        camps: String? = nil,
        result: String? = nil
    ) {
        self.tile = tile
        self.player = player
        self.other = other
        self.camps = camps
        self.result = result
    }

    public init(attributes: Attributes, children: Children) throws {
        self.tile = attributes["tile"]
        self.player = attributes["player"]
        self.other = attributes["other"]
        self.camps = attributes["camps"]
        self.result = attributes["result"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = tile { attrs["tile"] = v }
        if let v = player { attrs["player"] = v }
        if let v = other { attrs["other"] = v }
        if let v = camps { attrs["camps"] = v }
        if let v = result { attrs["result"] = v }
        return (attrs, [])
    }
}
