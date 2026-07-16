import Foundation

public struct DeclareIndependenceMessage: FreeColMessage {
    public static let tag = "declareIndependence"

    public let countryName: String?
    public let nationName: String?

    public init(
        countryName: String? = nil,
        nationName: String? = nil
    ) {
        self.countryName = countryName
        self.nationName = nationName
    }

    public init(attributes: Attributes, children: Children) throws {
        self.countryName = attributes["countryName"]
        self.nationName = attributes["nationName"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = countryName { attrs["countryName"] = v }
        if let v = nationName { attrs["nationName"] = v }
        return (attrs, [])
    }
}
