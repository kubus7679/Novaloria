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
            Text("Spielstand laden").font(.title2.bold())
            GroupBox("Spielstand und Java-Server") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Spielstand:")
                        Text(savegame?.path ?? "Keine Datei gewählt")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(savegame == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Wählen…") { chooseSavegame() }
                    }
                    GridRow {
                        Text("FreeCol-Installation:")
                        TextField("Ordner mit FreeCol.jar und data", text: $installationPath)
                        Button("Wählen…") { choosePath(directory: true) { installationPath = $0 } }
                    }
                    GridRow {
                        Text("Java-Programm:")
                        TextField("/Pfad/zu/bin/java", text: $javaPath)
                        Button("Wählen…") { choosePath(directory: false) { javaPath = $0 } }
                    }
                    GridRow {
                        Text("Partie:")
                        HStack {
                            TextField("Servername", text: $serverName)
                            Text("Port:")
                            TextField("3541", text: $port).frame(width: 70)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(6)
            }

            Text("Optionen, Karte und Regeln stammen aus dem Spielstand. Nach dem Start meldest du dich mit dem Namen eines menschlichen Spielers aus dem Spielstand an.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Der Server ist privat und nur auf diesem Mac erreichbar. Beim Trennen oder Beenden wird er gestoppt.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Server mit Spielstand starten") {
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
        .alert("Bisherige Lobby verlassen?", isPresented: $confirmDisconnect) {
            Button("Abbrechen", role: .cancel) {}
            Button("Spielstand laden", role: .destructive) { startServer() }
        } message: {
            Text("Die aktuelle Verbindung wird getrennt. Ein von dieser App gestarteter Server wird dabei beendet.")
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
                throw NewGameError.invalid("Bitte einen Port zwischen 1 und 65535 eingeben.")
            }
            try state.loadJavaSavegame(savegame,
                                       installation: URL(fileURLWithPath: NSString(string: installationPath).expandingTildeInPath),
                                       java: URL(fileURLWithPath: NSString(string: javaPath).expandingTildeInPath),
                                       port: port, name: serverName.isEmpty ? "Gespeicherte Partie" : serverName)
            onStarted(port)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
