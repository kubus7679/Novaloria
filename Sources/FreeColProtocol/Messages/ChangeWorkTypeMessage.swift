import Foundation

public struct ChangeWorkTypeMessage: FreeColMessage {
    public static let tag = "changeWorkType"

    public let unit: String?
    public let workType: String?

    public init(
        unit: String? = nil,
        workType: String? = nil
    ) {
        self.unit = unit
        self.workType = workType
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.workType = attributes["workType"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = workType { attrs["workType"] = v }
        return (attrs, [])
    }
}
