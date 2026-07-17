import Foundation

public struct ClaimLandMessage: FreeColMessage {
    public static let tag = "claimLand"

    public let claimant: String?
    public let price: String?
    public let tile: String?

    public init(
        claimant: String? = nil,
        price: String? = nil,
        tile: String? = nil
    ) {
        self.claimant = claimant
        self.price = price
        self.tile = tile
    }

    public init(attributes: Attributes, children: Children) throws {
        self.claimant = attributes["claimant"]
        self.price = attributes["price"]
        self.tile = attributes["tile"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = claimant { attrs["claimant"] = v }
        if let v = price { attrs["price"] = v }
        if let v = tile { attrs["tile"] = v }
        return (attrs, [])
    }
}
