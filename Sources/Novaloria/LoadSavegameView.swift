import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LoadSavegameView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @AppStorage("freecol.javaInstallation") private var installationPath = ""
    @AppStorage("freecol.javaExecutable") private var javaPath = "/usr/bin/java"
    @State private var savegame: URL?
    @State private var port = "3541"
    @State private var serverName = ""
    @State private var error: String?
    @State private var confirmDisconnect = false
    let onStarted: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("Spielstand laden", table: "LoadSavegameView")).font(.title2.bold())
            GroupBox(L10n.text("Spielstand und Java-Server", table: "LoadSavegameView")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text(L10n.text("Spielstand:", table: "LoadSavegameView"))
                        Text(savegame?.path ?? L10n.text("Keine Datei gewählt", table: "LoadSavegameView"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(savegame == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(L10n.text("Wählen…", table: "LoadSavegameView")) { chooseSavegame() }
                    }
                    GridRow {
                        Text(L10n.text("FreeCol-Installation:", table: "LoadSavegameView"))
                        TextField(L10n.text("Ordner mit FreeCol.jar und data", table: "LoadSavegameView"), text: $installationPath)
                        Button(L10n.text("Wählen…", table: "LoadSavegameView")) { choosePath(directory: true) { installationPath = $0 } }
                    }
                    GridRow {
                        Text(L10n.text("Java-Programm:", table: "LoadSavegameView"))
                        TextField(L10n.text("/Pfad/zu/bin/java", table: "LoadSavegameView"), text: $javaPath)
                        Button(L10n.text("Wählen…", table: "LoadSavegameView")) { choosePath(directory: false) { javaPath = $0 } }
                    }
                    GridRow {
                        Text(L10n.text("Partie:", table: "LoadSavegameView"))
                        HStack {
                            TextField(L10n.text("Servername", table: "LoadSavegameView"), text: $serverName)
                            Text(L10n.text("Port:", table: "LoadSavegameView"))
                            TextField(L10n.text("3541", table: "LoadSavegameView"), text: $port).frame(width: 70)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(6)
            }

            Text(L10n.text("Optionen, Karte und Regeln stammen aus dem Spielstand. Nach dem Start meldest du dich mit dem Namen eines menschlichen Spielers aus dem Spielstand an.", table: "LoadSavegameView"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.text("Der Server ist privat und nur auf diesem Mac erreichbar. Beim Trennen oder Beenden wird er gestoppt.", table: "LoadSavegameView"))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(L10n.text("Abbrechen", table: "LoadSavegameView")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("Server mit Spielstand starten", table: "LoadSavegameView")) {
                    if state.phase == .lobby { confirmDisconnect = true }
                    else { startServer() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(savegame == nil || installationPath.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 330)
        .onAppear {
            if installationPath.isEmpty {
                let sibling = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .deletingLastPathComponent().appendingPathComponent("freecol")
                if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("FreeCol.jar").path) {
                    installationPath = sibling.path
                }
            }
            if javaPath == "/usr/bin/java" {
                for candidate in ["/opt/homebrew/opt/openjdk/bin/java", "/usr/local/opt/openjdk/bin/java"]
                    where FileManager.default.isExecutableFile(atPath: candidate) {
                    javaPath = candidate
                    break
                }
            }
        }
        .alert(L10n.text("Bisherige Lobby verlassen?", table: "LoadSavegameView"), isPresented: $confirmDisconnect) {
            Button(L10n.text("Abbrechen", table: "LoadSavegameView"), role: .cancel) {}
            Button(L10n.text("Spielstand laden", table: "LoadSavegameView"), role: .destructive) { startServer() }
        } message: {
            Text(L10n.text("Die aktuelle Verbindung wird getrennt. Ein von dieser App gestarteter Server wird dabei beendet.", table: "LoadSavegameView"))
        }
    }

    private func chooseSavegame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let type = UTType(filenameExtension: "fsg") { panel.allowedContentTypes = [type] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        savegame = url
        serverName = url.deletingPathExtension().lastPathComponent
        error = nil
    }

    private func choosePath(directory: Bool, selected: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directory
        panel.canChooseFiles = !directory
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { selected(url.path) }
    }

    private func startServer() {
        guard let savegame else { return }
        do {
            guard let port = Int(port), (1...65535).contains(port) else {
                throw NewGameError.invalid(L10n.text("Bitte einen Port zwischen 1 und 65535 eingeben.", table: "LoadSavegameView"))
            }
            try state.loadJavaSavegame(savegame,
                                       installation: URL(fileURLWithPath: NSString(string: installationPath).expandingTildeInPath),
                                       java: URL(fileURLWithPath: NSString(string: javaPath).expandingTildeInPath),
                                       port: port, name: serverName.isEmpty ? L10n.text("Gespeicherte Partie", table: "LoadSavegameView") : serverName)
            onStarted(port)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
