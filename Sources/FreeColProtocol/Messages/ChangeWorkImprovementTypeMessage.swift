import Foundation

public struct ChangeWorkImprovementTypeMessage: FreeColMessage {
    public static let tag = "changeWorkImprovementType"

    public let unit: String?
    public let improvementType: String?

    public init(
        unit: String? = nil,
        improvementType: String? = nil
    ) {
        self.unit = unit
        self.improvementType = improvementType
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.improvementType = attributes["improvementType"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = improvementType { attrs["improvementType"] = v }
        return (attrs, [])
    }
}
