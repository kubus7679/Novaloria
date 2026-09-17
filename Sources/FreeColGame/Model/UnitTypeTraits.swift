import Foundation

/// Shared unit-type classification helpers.
///
/// The server does not currently expose unit-type roles/capabilities on the
/// wire in a form the client uses, so several UI guards fall back to
/// id/role name heuristics. Keeping the keyword lists here avoids the drift
/// that comes from duplicating them across `GameState` and `Specification`.
public enum UnitTypeTraits {
    /// Substrings that identify naval unit types.
    private static let navalKeywords = [
        "ship", "caravel", "galleon", "frigate", "manofwar", "man-of-war",
        "privateer", "merchant", "warship", "pinnace", "fluyt", "boat"
    ]

    /// Substrings that identify missionary units.
    private static let missionaryKeywords = ["missionary", "jesuit"]

    /// True when the unit type (or role) looks naval.
    public static func isNaval(unitType: String?, role: String? = nil) -> Bool {
        matches(keywords: navalKeywords, unitType: unitType, role: role)
    }

    /// True when the unit type (or role) looks like a missionary.
    public static func isMissionary(unitType: String?, role: String? = nil) -> Bool {
        matches(keywords: missionaryKeywords, unitType: unitType, role: role)
    }

    /// True when the unit type can plausibly carry cargo (ships/merchants).
    public static func isCarrier(unitType: String?, role: String? = nil) -> Bool {
        isNaval(unitType: unitType, role: role)
    }

    private static func matches(keywords: [String], unitType: String?, role: String?) -> Bool {
        let type = (unitType ?? "").lowercased()
        let roleValue = (role ?? "").lowercased()
        return keywords.contains { type.contains($0) || roleValue.contains($0) }
    }
}
