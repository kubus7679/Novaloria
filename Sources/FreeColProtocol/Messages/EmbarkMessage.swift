import Foundation

public struct EmbarkMessage: FreeColMessage {
    public static let tag = "embark"

    public let unit: String?
    public let direction: String?
    public let carrier: String?

    public init(
        unit: String? = nil,
        direction: String? = nil,
        carrier: String? = nil
    ) {
        self.unit = unit
        self.direction = direction
        self.carrier = carrier
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.direction = attributes["direction"]
        self.carrier = attributes["carrier"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = direction { attrs["direction"] = v }
        if let v = carrier { attrs["carrier"] = v }
        return (attrs, [])
    }
}
