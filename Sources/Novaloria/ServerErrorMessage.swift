import Foundation
import NovaloriaClient
import FreeColProtocol

enum ServerErrorMessage {
  static func description(for error: Error) -> String {
    if let actionError = error as? GameState.UserFacingActionError {
      return localize(actionError.message)
    }
    guard let protocolError = error as? FreeColProtocolError else {
      return technicalFailure(detail: error.localizedDescription)
    }
    switch protocolError {
    case .serverError(let raw): return userFacing(raw)
    case .timeout: return L10n.text("Der Server hat nicht rechtzeitig geantwortet. Bitte den Spielstand prüfen, bevor du die Aktion erneut ausführst.", table: "ServerErrorMessage")
    case .disconnected: return L10n.text("Die Verbindung zum Server wurde getrennt.", table: "ServerErrorMessage")
    default: return technicalFailure(detail: protocolError.localizedDescription)
    }
  }

  static func technicalFailure(detail: String) -> String {
    L10n.text("Ein technischer Fehler ist aufgetreten: \(detail)", table: "ServerErrorMessage")
  }

  static func userFacing(_ raw: String) -> String {
    localize(ServerRejectMapper.userFacingMessage(forServerMessage: raw))
  }

  static func rejection(for parsed: ParsedMessage) -> String {
    localize(ServerRejectMapper.userFacingMessage(for: parsed))
  }

  private static let translationKeys: [String: String.LocalizationValue] = [
    "Nur der Admin kann das Spiel starten.": "Nur der Admin kann das Spiel starten.",
    "Nicht alle Spieler sind bereit.": "Nicht alle Spieler sind bereit.",
    "Server hat die Aktion abgelehnt.": "Server hat die Aktion abgelehnt.",
    "Dieser Spielername wird bereits verwendet.": "Dieser Spielername wird bereits verwendet.",
    "Diese Einheit hat keine Bewegungspunkte mehr.": "Diese Einheit hat keine Bewegungspunkte mehr.",
    "Die Einheit kann hier keine Kolonie gründen.": "Die Einheit kann hier keine Kolonie gründen.",
    "Diese Einheit kann der Kolonie nicht beitreten.": "Diese Einheit kann der Kolonie nicht beitreten.",
    "Diese Einheit kann nicht eingeschifft werden.": "Diese Einheit kann nicht eingeschifft werden.",
    "Diese Einheit ist eingeschifft; bitte zuerst ausschiffen.": "Diese Einheit ist eingeschifft; bitte zuerst ausschiffen.",
    "Diese Einheit kann nicht ausgeschifft werden.": "Diese Einheit kann nicht ausgeschifft werden.",
    "Angriff ist nicht moeglich.": "Angriff ist nicht moeglich.",
    "Nicht genug Gold.": "Nicht genug Gold.",
    "Diese Einheit kann nicht über Wasser gehen.": "Diese Einheit kann nicht über Wasser gehen.",
    "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug.": "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug.",
    "Handel nicht möglich.": "Handel nicht möglich.",
    "Der Händler bricht das Feilschen ab.": "Der Händler bricht das Feilschen ab.",
    "Die Siedlung ist feindlich gesinnt.": "Die Siedlung ist feindlich gesinnt.",
    "Diese Bewegung ist nicht erlaubt.": "Diese Bewegung ist nicht erlaubt.",
    "Die Einheit ist auf dem Server nicht bekannt.": "Die Einheit ist auf dem Server nicht bekannt.",
    "Der Koloniename ist bereits vergeben.": "Der Koloniename ist bereits vergeben.",
    "Bitte einen Kolonienamen eingeben.": "Bitte einen Kolonienamen eingeben.",
    "Der Zug konnte nicht beendet werden. Bitte versuche es erneut.": "Der Zug konnte nicht beendet werden. Bitte versuche es erneut.",
    "Die Einheit befindet sich nicht auf der Karte.": "Die Einheit befindet sich nicht auf der Karte.",
    "Die Einheit befindet sich nicht in einer Kolonie.": "Die Einheit befindet sich nicht in einer Kolonie.",
    "Zum Ausrüsten muss die Einheit in einer geeigneten Siedlung sein.": "Zum Ausrüsten muss die Einheit in einer geeigneten Siedlung sein.",
    "Dieser Arbeitsplatz ist nicht verfügbar.": "Dieser Arbeitsplatz ist nicht verfügbar.",
    "Dieser Arbeitsplatz gehört nicht zur Kolonie.": "Dieser Arbeitsplatz gehört nicht zur Kolonie.",
    "Die Einheit kann an diesem Arbeitsplatz nicht eingesetzt werden.": "Die Einheit kann an diesem Arbeitsplatz nicht eingesetzt werden.",
    "Zum Warenhandel muss der Transporter in Europa oder einer geeigneten Siedlung sein.": "Zum Warenhandel muss der Transporter in Europa oder einer geeigneten Siedlung sein.",
    "Diese Einheit kann keine Waren transportieren.": "Diese Einheit kann keine Waren transportieren.",
    "Die Warenmenge muss größer als null sein.": "Die Warenmenge muss größer als null sein.",
    "Bitte eine gültige Warenmenge eingeben.": "Bitte eine gültige Warenmenge eingeben.",
    "Für den Kauf dieses Feldes fehlt Gold.": "Für den Kauf dieses Feldes fehlt Gold.",
    "Dieses Feld kann nicht beansprucht werden.": "Dieses Feld kann nicht beansprucht werden.",
    "Dieses Feld liegt außerhalb des Koloniegeländes.": "Dieses Feld liegt außerhalb des Koloniegeländes.",
    "Diese Einheit kann nicht diplomatisch verhandeln.": "Diese Einheit kann nicht diplomatisch verhandeln.",
    "Diese Verhandlung ist nicht mehr aktiv. Bitte erneut öffnen.": "Diese Verhandlung ist nicht mehr aktiv. Bitte erneut öffnen.",
    "Die Einheit kann mit der vorhandenen Ausrüstung nicht für diese Rolle ausgerüstet werden.": "Die Einheit kann mit der vorhandenen Ausrüstung nicht für diese Rolle ausgerüstet werden.",
  ]

  private static func localize(_ message: String) -> String {
    if let key = translationKeys[message] {
      return L10n.text(key, table: "ServerErrorMessage")
    }
    let prefix = "Der Server hat die Aktion abgelehnt: "
    guard message.hasPrefix(prefix) else { return message }
    let details = String(message.dropFirst(prefix.count))
    return L10n.text("Der Server hat die Aktion abgelehnt: \(details)", table: "ServerErrorMessage")
  }
}
