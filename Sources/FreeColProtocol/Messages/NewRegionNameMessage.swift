import Foundation

public struct NewRegionNameMessage: FreeColMessage {
    public static let tag = "newRegionName"

    public let unit: String?
    public let newRegionName: String?
    public let tile: String?
    public let region: String?

    public init(
        unit: String? = nil,
        newRegionName: String? = nil,
        tile: String? = nil,
        region: String? = nil
    ) {
        self.unit = unit
        self.newRegionName = newRegionName
        self.tile = tile
        self.region = region
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.newRegionName = attributes["newRegionName"]
        self.tile = attributes["tile"]
        self.region = attributes["region"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = newRegionName { attrs["newRegionName"] = v }
        if let v = tile { attrs["tile"] = v }
        if let v = region { attrs["region"] = v }
        return (attrs, [])
    }
}
