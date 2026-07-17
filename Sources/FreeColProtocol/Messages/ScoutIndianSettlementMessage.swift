import Foundation

public struct ScoutIndianSettlementMessage: FreeColMessage {
    public static let tag = "scoutIndianSettlement"

    public let unit: String?
    public let direction: String?

    public init(
        unit: String? = nil,
        direction: String? = nil
    ) {
        self.unit = unit
        self.direction = direction
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.direction = attributes["direction"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = direction { attrs["direction"] = v }
        return (attrs, [])
    }
}
