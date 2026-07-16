import Foundation

public struct TrainUnitInEuropeMessage: FreeColMessage {
    public static let tag = "trainUnitInEurope"

    public let unitType: String?

    public init(
        unitType: String? = nil
    ) {
        self.unitType = unitType
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unitType = attributes["unitType"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unitType { attrs["unitType"] = v }
        return (attrs, [])
    }
}
