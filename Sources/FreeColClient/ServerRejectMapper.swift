import Foundation
import FreeColProtocol

public enum ServerRejectMapper {
    public static func userFacingMessage(for parsed: ParsedMessage) -> String {
        if let message = parsed.attributes["message"], !message.isEmpty {
            return userFacingMessage(forServerMessage: message)
        }
        if let template = parsed.children.first(where: { $0.tag == "stringTemplate" }),
           let templateId = template.attributes["id"] {
            return userFacingMessage(forServerMessage: templateId)
        }
        return "Server hat die Aktion abgelehnt."
    }

    public static func rejectedObjectId(prefix: String, in message: String) -> String? {
        for rawToken in message.split(separator: " ") {
            let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ":;,()[]{}"))
            if token.hasPrefix(prefix) {
                return String(token)
            }
        }
        return nil
    }

    public static func userFacingMessage(forServerMessage message: String) -> String {
        let normalized = message.lowercased()
        switch message {
        case "server.onlyAdminCanLaunch": return "Nur der Admin kann das Spiel starten."
        case "server.notAllReady": return "Nicht alle Spieler sind bereit."
        case "server.reject": return "Server hat die Aktion abgelehnt."
        case "server.userNameInUse": return "Dieser Spielername wird bereits verwendet."
        default: break
        }
        if normalized.contains("move_no_moves") {
            return "Diese Einheit hat keine Bewegungspunkte mehr."
        }
        if normalized.contains("can not build colony") {
            return "Die Einheit kann hier keine Kolonie gründen."
        }
        if normalized.contains("can not join colony") {
            return "Diese Einheit kann der Kolonie nicht beitreten."
        }
        if normalized.contains("can not embark") {
            return "Diese Einheit kann nicht eingeschifft werden."
        }
        if normalized.contains("move_no_access_embark") {
            return "Diese Einheit ist eingeschifft; bitte zuerst ausschiffen."
        }
        if normalized.contains("can not disembark") {
            return "Diese Einheit kann nicht ausgeschifft werden."
        }
        if normalized.contains("can not attack") {
            return "Angriff ist nicht moeglich."
        }
        if normalized.contains("not enough gold") {
            return "Nicht genug Gold."
        }
        if normalized.contains("move_no_amphibious") {
            return "Diese Einheit kann nicht über Wasser gehen."
        }
        if normalized.contains("not your turn") || normalized.contains("not the current player")
            || normalized.contains("not allowed to end turn")
            || (normalized.hasPrefix("it is not ") && normalized.contains("turn")) {
            return "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug."
        }
        if normalized.contains("native trade") || normalized.contains("can not trade") {
            return "Handel nicht möglich."
        }
        if normalized.contains("too much haggling") || normalized.contains("nak_haggle") {
            return "Der Händler bricht das Feilschen ab."
        }
        if normalized.contains("hostile") {
            return "Die Siedlung ist feindlich gesinnt."
        }
        // Specific movement failures above must win over the generic illegal-move text.
        if normalized.contains("illegal move") {
            return "Diese Bewegung ist nicht erlaubt."
        }
        if normalized.hasPrefix("not a net.sf.freecol.server.model.serverunit:") {
            return "Die Einheit ist auf dem Server nicht bekannt."
        }
        if normalized.hasPrefix("non-unique colony name") {
            return "Der Koloniename ist bereits vergeben."
        }
        if normalized.hasPrefix("null colony name") {
            return "Bitte einen Kolonienamen eingeben."
        }
        if normalized.contains("end turn") && (normalized.contains("fail") || normalized.contains("reject")) {
            return "Der Zug konnte nicht beendet werden. Bitte versuche es erneut."
        }
        let prefixes: [(String, String)] = [
            ("unit is not on the map:", "Die Einheit befindet sich nicht auf der Karte."),
            ("unit is not at a colony:", "Die Einheit befindet sich nicht in einer Kolonie."),
            ("unit is not in a settlement:", "Zum Ausrüsten muss die Einheit in einer geeigneten Siedlung sein."),
            ("not a work location:", "Dieser Arbeitsplatz ist nicht verfügbar."),
            ("work location is not in colony", "Dieser Arbeitsplatz gehört nicht zur Kolonie."),
            ("can not add ", "Die Einheit kann an diesem Arbeitsplatz nicht eingesetzt werden."),
            ("not at a trade location:", "Zum Warenhandel muss der Transporter in Europa oder einer geeigneten Siedlung sein."),
            ("not a goods carrier:", "Diese Einheit kann keine Waren transportieren."),
            ("amount must be positive:", "Die Warenmenge muss größer als null sein."),
            ("bad amount:", "Bitte eine gültige Warenmenge eingeben."),
            ("can not pay for tile:", "Für den Kauf dieses Feldes fehlt Gold."),
            ("can not claim tile ", "Dieses Feld kann nicht beansprucht werden."),
            ("settlement can not claim tile:", "Dieses Feld liegt außerhalb des Koloniegeländes."),
            ("unit lacks ability to negotiate:", "Diese Einheit kann nicht diplomatisch verhandeln."),
            ("missing uc-diplomacy session", "Diese Verhandlung ist nicht mehr aktiv. Bitte erneut öffnen."),
            ("missing cu-diplomacy session", "Diese Verhandlung ist nicht mehr aktiv. Bitte erneut öffnen."),
            ("failed to equip ", "Die Einheit kann mit der vorhandenen Ausrüstung nicht für diese Rolle ausgerüstet werden."),
        ]
        if let match = prefixes.first(where: { normalized.hasPrefix($0.0) }) { return match.1 }
        return "Der Server hat die Aktion abgelehnt: \(message)"
    }
}
