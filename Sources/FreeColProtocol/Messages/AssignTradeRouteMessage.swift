import Foundation

public struct AssignTradeRouteMessage: FreeColMessage {
    public static let tag = "assignTradeRoute"

    public let unit: String?
    public let tradeRoute: String?

    public init(
        unit: String? = nil,
        tradeRoute: String? = nil
    ) {
        self.unit = unit
        self.tradeRoute = tradeRoute
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.tradeRoute = attributes["tradeRoute"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = tradeRoute { attrs["tradeRoute"] = v }
        return (attrs, [])
    }
}
