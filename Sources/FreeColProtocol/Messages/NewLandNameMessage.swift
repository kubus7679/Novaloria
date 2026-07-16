import Foundation

public struct NewLandNameMessage: FreeColMessage {
    public static let tag = "newLandName"

    public let unit: String?
    public let newLandName: String?

    public init(
        unit: String? = nil,
        newLandName: String? = nil
    ) {
        self.unit = unit
        self.newLandName = newLandName
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.newLandName = attributes["newLandName"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = newLandName { attrs["newLandName"] = v }
        return (attrs, [])
    }
}
