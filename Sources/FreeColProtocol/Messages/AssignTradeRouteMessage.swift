import Foundation

public struct AssignTradeRouteMessage: FreeColMessage {
    public static let tag = "assignTradeRoute"

    public let tradeRoute: String?
    public let unit: String?

    public init(
        tradeRoute: String? = nil,
        unit: String? = nil
    ) {
        self.tradeRoute = tradeRoute
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.tradeRoute = attributes["tradeRoute"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = tradeRoute { attrs["tradeRoute"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
