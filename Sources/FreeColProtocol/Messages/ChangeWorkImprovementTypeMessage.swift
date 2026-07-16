import Foundation

public struct ChangeWorkImprovementTypeMessage: FreeColMessage {
    public static let tag = "changeWorkImprovementType"

    public let improvementType: String?
    public let unit: String?

    public init(
        improvementType: String? = nil,
        unit: String? = nil
    ) {
        self.improvementType = improvementType
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.improvementType = attributes["improvementType"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = improvementType { attrs["improvementType"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
