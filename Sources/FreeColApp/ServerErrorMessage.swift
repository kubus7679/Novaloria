import Foundation

enum ServerErrorMessage {
  static func userFacing(_ raw: String) -> String {
    if raw.contains("ServerUnit") {
      return "Die Einheit ist auf dem Server nicht bekannt."
    }
    if raw.contains("Illegal move") {
      return "Diese Bewegung ist nicht erlaubt."
    }
    if raw.contains("can not build colony") {
      return "Die Einheit kann hier keine Kolonie gründen."
    }
    if raw.contains("Non-unique colony name") {
      return "Der Koloniename ist bereits vergeben."
    }
    if raw.contains("Null colony name") {
      return "Bitte einen Kolonienamen eingeben."
    }
    if raw.localizedCaseInsensitiveContains("not the current player")
      || raw.localizedCaseInsensitiveContains("not your turn")
      || raw.localizedCaseInsensitiveContains("not allowed to end turn")
    {
      return "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug."
    }
    if raw.localizedCaseInsensitiveContains("end turn")
      && (raw.localizedCaseInsensitiveContains("fail")
        || raw.localizedCaseInsensitiveContains("reject"))
    {
      return "Der Zug konnte nicht beendet werden. Bitte versuche es erneut."
    }
    return "Der Server hat die Aktion abgelehnt: \(raw)"
  }
}
