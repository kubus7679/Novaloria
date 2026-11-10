import AppKit
import UniformTypeIdentifiers

extension GameState {
    func showSaveGamePanel() {
        guard canSaveGame else {
            errorMessage = L10n.text("Speichern ist nur als Spieladministrator im eigenen Zug auf einem Java-Server möglich.", table: "GameState+Saving")
            return
        }
        let panel = NSSavePanel()
        panel.title = L10n.text("Spiel speichern", table: "GameState+Saving")
        panel.message = L10n.text("Vollständiger Server-Spielstand (.fsg). Der Java-Server muss mit der NovaloriaClient-Speichererweiterung gestartet sein.", table: "GameState+Saving")
        panel.allowedContentTypes = [UTType(filenameExtension: "fsg") ?? .data]
        panel.nameFieldStringValue = L10n.text("FreeCol-Runde-\(game?.turn.number ?? 1).fsg", table: "GameState+Saving")
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.saveGame(to: url)
        }
    }
}
