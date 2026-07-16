import Foundation

public struct SetCurrentStopMessage: FreeColMessage {
    public static let tag = "setCurrentStop"

    public let index: String?
    public let unit: String?

    public init(
        index: String? = nil,
        unit: String? = nil
    ) {
        self.index = index
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.index = attributes["index"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = index { attrs["index"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
