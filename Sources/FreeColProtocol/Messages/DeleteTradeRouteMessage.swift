import Foundation

public struct DeleteTradeRouteMessage: FreeColMessage {
    public static let tag = "deleteTradeRoute"

    public let tradeRoute: String?

    public init(
        tradeRoute: String? = nil
    ) {
        self.tradeRoute = tradeRoute
    }

    public init(attributes: Attributes, children: Children) throws {
        self.tradeRoute = attributes["tradeRoute"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = tradeRoute { attrs["tradeRoute"] = v }
        return (attrs, [])
    }
}
