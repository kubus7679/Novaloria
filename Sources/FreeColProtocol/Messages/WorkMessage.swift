import Foundation

public struct WorkMessage: FreeColMessage {
    public static let tag = "work"

    public let unit: String?
    public let workLocation: String?

    public init(
        unit: String? = nil,
        workLocation: String? = nil
    ) {
        self.unit = unit
        self.workLocation = workLocation
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.workLocation = attributes["workLocation"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = workLocation { attrs["workLocation"] = v }
        return (attrs, [])
    }
}
