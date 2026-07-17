import Foundation

public struct SetCurrentStopMessage: FreeColMessage {
    public static let tag = "setCurrentStop"

    public let unit: String?
    public let index: String?

    public init(
        unit: String? = nil,
        index: String? = nil
    ) {
        self.unit = unit
        self.index = index
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.index = attributes["index"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = index { attrs["index"] = v }
        return (attrs, [])
    }
}
