import SwiftUI
import AppKit

struct NewGameView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @AppStorage("freecol.javaInstallation") private var installationPath = ""
    @AppStorage("freecol.javaExecutable") private var javaPath = "/usr/bin/java"
    @State private var difficulty: GameDifficulty = .medium
    @State private var configuration: NewGameConfiguration?
    @State private var selectedSection: String?
    @State private var port = "3541"
    @State private var serverName = "Neue Welt"
    @State private var seed = ""
    @State private var error: String?
    @State private var confirmDisconnect = false
    let onCreated: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Neues Spiel erstellen").font(.title2.bold())
            GroupBox("Java-Server") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
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
                            Text("Zufallsstartwert:")
                            TextField("Zufällig", text: $seed).frame(width: 140)
                        }
                    }
                    GridRow {
                        Text("Schwierigkeit:")
                        HStack {
                            Picker("Schwierigkeit", selection: $difficulty) {
                                ForEach(GameDifficulty.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                            Button("Optionen laden") { loadOptions() }
                            Text("Vorlagenwechsel setzt alle Optionen zurück.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(6)
            }

            if let configuration {
                HSplitView {
                    List(configuration.sections, selection: $selectedSection) { section in
                        Text(configuration.label(section.id)).tag(section.id)
                    }
                    .frame(minWidth: 190, idealWidth: 240, maxWidth: 310)
                    ScrollView {
                        if let section = configuration.sections.first(where: { $0.id == selectedSection }) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(configuration.label(section.id)).font(.headline)
                                ForEach(section.options) { option in
                                    optionRow(option, configuration: configuration)
                                    Divider()
                                }
                            }
                            .padding()
                        }
                    }
                    .frame(minWidth: 420)
                }
                Text("\(configuration.values.count) Optionen aus der Java-Installation, einschließlich Karte und Schwierigkeit. Einheitenlisten sind als XML bearbeitbar.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("Spieloptionen laden", systemImage: "slider.horizontal.3",
                                       description: Text("Wähle die FreeCol-Installation und lade ihre vollständigen Spieloptionen."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Der Server ist privat und nur auf diesem Mac erreichbar. Beim Trennen oder Beenden wird er gestoppt. Optionen und Protokolle bleiben pro Partie gespeichert.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Optionsdatei exportieren…") { exportOptions() }
                    .disabled(configuration == nil)
                Button("Spiel erstellen") {
                    if state.phase == .lobby { confirmDisconnect = true }
                    else { createGame() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(configuration == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 940, idealWidth: 1040, minHeight: 700, idealHeight: 780)
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
            if !installationPath.isEmpty { loadOptions() }
        }
        .onChange(of: installationPath) { _, path in
            let selected = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                .standardizedFileURL.resolvingSymlinksInPath()
            if configuration?.installation != selected { configuration = nil }
            error = nil
        }
        .onChange(of: difficulty) { _, _ in
            if configuration != nil { loadOptions() }
        }
        .alert("Bisherige Lobby verlassen?", isPresented: $confirmDisconnect) {
            Button("Abbrechen", role: .cancel) {}
            Button("Neue Partie erstellen", role: .destructive) { createGame() }
        } message: {
            Text("Die aktuelle Verbindung wird getrennt. Ein von dieser App gestarteter Server wird dabei beendet.")
        }
    }

    @ViewBuilder
    private func optionRow(_ option: GameSetupOption, configuration: NewGameConfiguration) -> some View {
        let binding = Binding(
            get: { self.configuration?.values[option.id] ?? option.initialValue },
            set: { self.configuration?.values[option.id] = $0; error = nil }
        )
        VStack(alignment: .leading, spacing: 5) {
            if option.isBoolean {
                Toggle(configuration.label(option.id), isOn: Binding(
                    get: { binding.wrappedValue == "true" },
                    set: { binding.wrappedValue = $0 ? "true" : "false" }
                ))
            } else if !option.choices.isEmpty {
                Picker(configuration.label(option.id), selection: binding) {
                    ForEach(option.choices, id: \.value) { choice in
                        Text(configuration.label(choice.label)).tag(choice.value)
                    }
                }
            } else {
                Text(configuration.label(option.id))
                if option.isXML {
                    TextEditor(text: binding)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 180)
                        .border(.secondary.opacity(0.3))
                } else {
                    HStack {
                        TextField("", text: binding).textFieldStyle(.roundedBorder)
                        if option.node.tag == "fileOption" {
                            Button("Wählen…") { choosePath(directory: false) { binding.wrappedValue = $0 } }
                        }
                    }
                }
            }
            if let description = configuration.labels[option.id + ".shortDescription"] {
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Text(option.id).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
            if let minimum = option.node.attributes["minimumValue"],
               let maximum = option.node.attributes["maximumValue"] {
                Text("Bereich: \(minimum) bis \(maximum)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func choosePath(directory: Bool, selected: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directory
        panel.canChooseFiles = !directory
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { selected(url.path) }
    }

    private func loadOptions() {
        do {
            let loaded = try NewGameConfiguration.load(installation: URL(fileURLWithPath: NSString(string: installationPath).expandingTildeInPath),
                                                       difficulty: difficulty)
            configuration = loaded
            selectedSection = loaded.sections.first?.id
            error = nil
        } catch {
            configuration = nil
            self.error = error.localizedDescription
        }
    }

    private func exportOptions() {
        guard let configuration else { return }
        do {
            let xml = try configuration.specificationXML()
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "game-options.xml"
            if panel.runModal() == .OK, let url = panel.url {
                try xml.write(to: url, atomically: true, encoding: .utf8)
                error = nil
            }
        } catch { self.error = error.localizedDescription }
    }

    private func createGame() {
        guard let configuration else { return }
        do {
            guard let port = Int(port), (1...65535).contains(port) else {
                throw NewGameError.invalid("Bitte einen Port zwischen 1 und 65535 eingeben.")
            }
            try state.createJavaGame(configuration: configuration, java: URL(fileURLWithPath: NSString(string: javaPath).expandingTildeInPath),
                                     port: port, name: serverName, seed: seed)
            onCreated(port)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
