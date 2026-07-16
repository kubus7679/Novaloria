import Foundation
import FreeColProtocol

// MARK: - Protocols

/// Any game object that can be deserialized from a ParsedMessage.
public protocol GameObject {
    var id: String { get }
    init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws
}

/// An object that can be partially updated.
public protocol PartiallyUpdatable: GameObject {
    mutating func applyPartial(attributes: Attributes) throws
}

// MARK: - Helper extensions

extension Attributes {
    func string(_ key: String) -> String? { self[key] }
    func int(_ key: String, default defaultValue: Int = 0) -> Int {
        guard let v = self[key], let n = Int(v) else { return defaultValue }
        return n
    }
    func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let v = self[key] else { return defaultValue }
        return (v as NSString).boolValue
    }
    func enumValue<T: RawRepresentable>(_ key: String, default defaultValue: T) -> T where T.RawValue == String {
        guard let v = self[key], let e = T(rawValue: v) else { return defaultValue }
        return e
    }
}
