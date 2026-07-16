import Foundation

public struct ScoutSpeakToChiefMessage: FreeColMessage {
    public static let tag = "scoutSpeakToChief"

    public let settlement: String?
    public let unit: String?
    public let result: String?

    public init(
        settlement: String? = nil,
        unit: String? = nil,
        result: String? = nil
    ) {
        self.settlement = settlement
        self.unit = unit
        self.result = result
    }

    public init(attributes: Attributes, children: Children) throws {
        self.settlement = attributes["settlement"]
        self.unit = attributes["unit"]
        self.result = attributes["result"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = settlement { attrs["settlement"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = result { attrs["result"] = v }
        return (attrs, [])
    }
}
