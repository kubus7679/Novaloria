import Foundation

public struct ClaimLandMessage: FreeColMessage {
    public static let tag = "claimLand"

    public let price: String?
    public let claimant: String?
    public let tile: String?

    public init(
        price: String? = nil,
        claimant: String? = nil,
        tile: String? = nil
    ) {
        self.price = price
        self.claimant = claimant
        self.tile = tile
    }

    public init(attributes: Attributes, children: Children) throws {
        self.price = attributes["price"]
        self.claimant = attributes["claimant"]
        self.tile = attributes["tile"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = price { attrs["price"] = v }
        if let v = claimant { attrs["claimant"] = v }
        if let v = tile { attrs["tile"] = v }
        return (attrs, [])
    }
}
