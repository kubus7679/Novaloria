import AppKit
import UniformTypeIdentifiers

extension GameState {
    func showSaveGamePanel() {
        guard canSaveGame else {
            errorMessage = "Speichern ist nur als Spieladministrator im eigenen Zug auf einem Java-Server möglich."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Spiel speichern"
        panel.message = "Vollständiger Server-Spielstand (.fsg). Der Java-Server muss mit der NovaloriaClient-Speichererweiterung gestartet sein."
        panel.allowedContentTypes = [UTType(filenameExtension: "fsg") ?? .data]
        panel.nameFieldStringValue = "FreeCol-Runde-\(game?.turn.number ?? 1).fsg"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.saveGame(to: url)
        }
    }
}
