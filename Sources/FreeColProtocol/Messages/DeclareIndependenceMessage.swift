import Foundation

public struct DeclareIndependenceMessage: FreeColMessage {
    public static let tag = "declareIndependence"

    public let nationName: String?
    public let countryName: String?

    public init(
        nationName: String? = nil,
        countryName: String? = nil
    ) {
        self.nationName = nationName
        self.countryName = countryName
    }

    public init(attributes: Attributes, children: Children) throws {
        self.nationName = attributes["nationName"]
        self.countryName = attributes["countryName"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = nationName { attrs["nationName"] = v }
        if let v = countryName { attrs["countryName"] = v }
        return (attrs, [])
    }
}
