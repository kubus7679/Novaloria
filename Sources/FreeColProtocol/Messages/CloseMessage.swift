import Foundation

public struct CloseMessage: FreeColMessage {
    public static let tag = "close"

    public let panel: String?

    public init(
        panel: String? = nil
    ) {
        self.panel = panel
    }

    public init(attributes: Attributes, children: Children) throws {
        self.panel = attributes["panel"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = panel { attrs["panel"] = v }
        return (attrs, [])
    }
}
