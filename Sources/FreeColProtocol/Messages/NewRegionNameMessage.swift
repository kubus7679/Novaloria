import Foundation

public struct NewRegionNameMessage: FreeColMessage {
    public static let tag = "newRegionName"

    public let region: String?
    public let newRegionName: String?
    public let tile: String?
    public let unit: String?

    public init(
        region: String? = nil,
        newRegionName: String? = nil,
        tile: String? = nil,
        unit: String? = nil
    ) {
        self.region = region
        self.newRegionName = newRegionName
        self.tile = tile
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.region = attributes["region"]
        self.newRegionName = attributes["newRegionName"]
        self.tile = attributes["tile"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = region { attrs["region"] = v }
        if let v = newRegionName { attrs["newRegionName"] = v }
        if let v = tile { attrs["tile"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
