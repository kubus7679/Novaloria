import Foundation
import FreeColProtocol

/// A stop on a trade route: a location (colony / Europe) plus the goods types
/// the carrier should leave the stop with.
public struct TradeRouteStop: Sendable, Equatable, Identifiable {
    public var id: String { locationId ?? UUID().uuidString }
    public var locationId: String?
    public var cargoTypeIds: [String]

    public init(locationId: String?, cargoTypeIds: [String] = []) {
        self.locationId = locationId
        self.cargoTypeIds = cargoTypeIds
    }

    public init(parsed: ParsedMessage) {
        self.locationId = parsed.attributes["location"]
        self.cargoTypeIds = parsed.children
            .filter { $0.tag == "cargo" }
            .compactMap { $0.attributes["id"] }
    }
}

/// A player trade route as serialized by the Java server.
public struct TradeRoute: GameObject, PartiallyUpdatable, Identifiable {
    public var id: String
    public var name: String?
    public var owner: String?
    public var silent: Bool = false
    public var stops: [TradeRouteStop] = []

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
        stops = children
            .filter { $0.tag == "tradeRouteStop" }
            .map { TradeRouteStop(parsed: $0) }
    }

    /// Local construction for the editor.
    public init(id: String,
                name: String,
                owner: String?,
                silent: Bool = false,
                stops: [TradeRouteStop] = []) {
        self.id = id
        self.name = name
        self.owner = owner
        self.silent = silent
        self.stops = stops
    }

    public mutating func applyPartial(attributes: Attributes) {
        if let v = attributes["name"] { name = v }
        if let v = attributes["owner"] { owner = v }
        silent = attributes.bool("silent", default: silent)
    }
}
