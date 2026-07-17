import Foundation

public struct NewRegionNameMessage: FreeColMessage {
    public static let tag = "newRegionName"

    public let unit: String?
    public let region: String?
    public let newRegionName: String?
    public let tile: String?

    public init(
        unit: String? = nil,
        region: String? = nil,
        newRegionName: String? = nil,
        tile: String? = nil
    ) {
        self.unit = unit
        self.region = region
        self.newRegionName = newRegionName
        self.tile = tile
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.region = attributes["region"]
        self.newRegionName = attributes["newRegionName"]
        self.tile = attributes["tile"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = region { attrs["region"] = v }
        if let v = newRegionName { attrs["newRegionName"] = v }
        if let v = tile { attrs["tile"] = v }
        return (attrs, [])
    }
}
