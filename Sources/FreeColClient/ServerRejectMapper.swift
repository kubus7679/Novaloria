import Foundation
import FreeColProtocol

public enum ServerRejectMapper {
    public static func userFacingMessage(for parsed: ParsedMessage) -> String {
        if let message = parsed.attributes["message"], !message.isEmpty {
            return userFacingMessage(forServerMessage: message)
        }
        if let template = parsed.children.first(where: { $0.tag == "stringTemplate" }),
           let templateId = template.attributes["id"] {
            return userFacingMessage(forTemplateId: templateId)
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

    private static func userFacingMessage(forServerMessage message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("move_no_moves") {
            return "Diese Einheit hat keine Bewegungspunkte mehr."
        }
        if normalized.contains("can not build colony") {
            return "Diese Einheit kann hier keine Kolonie gruenden."
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
        if normalized.contains("not your turn") || normalized.contains("it is not") {
            return "Du bist gerade nicht am Zug."
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
        return message
    }

    private static func userFacingMessage(forTemplateId templateId: String) -> String {
        switch templateId {
        case "server.onlyAdminCanLaunch":
            return "Nur der Admin kann das Spiel starten."
        case "server.notAllReady":
            return "Nicht alle Spieler sind bereit."
        case "server.reject":
            return "Server hat die Aktion abgelehnt."
        default:
            return templateId
        }
    }
}
