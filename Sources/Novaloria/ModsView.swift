import SwiftUI
import AppKit

struct ModsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("freecol.javaInstallation") private var installationPath = ""
    @AppStorage(FreeColModSelection.storageKey) private var activeModIDsData = "[]"
    @State private var mods: [FreeColMod] = []

    private var activeIDs: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data(activeModIDsData.utf8))) ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.text("Mods", table: "ModsView"))
                    .font(.title2.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "ModsView")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            GroupBox(L10n.text("FreeCol-Installation", table: "ModsView")) {
                HStack {
                    TextField(L10n.text("Ordner mit FreeCol.jar und data", table: "ModsView"), text: $installationPath)
                        .textFieldStyle(.roundedBorder)
                    Button(L10n.text("Wählen…", table: "ModsView")) { chooseInstallation() }
                }
            }

            Text(L10n.text(
                "Grafik-Mods werden auf der Karte sowie bei Einheiten-, Siedlungs- und Warenbildern verwendet. Regeländernde Mods gelten für neu erstellte lokale Partien. Bei einem fremden Server legt der Server die Spielregeln fest.",
                table: "ModsView"
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if mods.isEmpty {
                ContentUnavailableView(
                    L10n.text("Keine Mods gefunden", table: "ModsView"),
                    systemImage: "puzzlepiece.extension",
                    description: Text(L10n.text(
                        "Wähle eine FreeCol-Installation mit Mods im Ordner data/mods.",
                        table: "ModsView"
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(mods) { mod in
                    HStack(alignment: .top, spacing: 12) {
                        Toggle("", isOn: selection(for: mod))
                            .labelsHidden()
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(mod.name).font(.headline)
                                if mod.hasSpecification {
                                    Label(L10n.text("Regeln + Grafik", table: "ModsView"), systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Label(L10n.text("Grafik", table: "ModsView"), systemImage: "photo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(mod.description.isEmpty ? mod.id : mod.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }

            HStack {
                Text(L10n.text("\(mods.filter { activeIDs.contains($0.id) }.count) Mods aktiviert", table: "ModsView"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Deaktivieren", table: "ModsView")) {
                    save([])
                }
                .disabled(activeIDs.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 620, idealWidth: 720, minHeight: 460, idealHeight: 580)
        .onAppear {
            if installationPath.isEmpty {
                let sibling = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .deletingLastPathComponent().appendingPathComponent("freecol")
                if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("FreeCol.jar").path) {
                    installationPath = sibling.path
                }
            }
            refresh()
        }
        .onChange(of: installationPath) { _, _ in refresh() }
    }

    private func selection(for mod: FreeColMod) -> Binding<Bool> {
        Binding(
            get: { activeIDs.contains(mod.id) },
            set: { enabled in
                var updated = activeIDs
                if enabled { updated.insert(mod.id) }
                else { updated.remove(mod.id) }
                save(updated)
            }
        )
    }

    private func save(_ ids: Set<String>) {
        let data = (try? JSONEncoder().encode(ids.sorted())) ?? Data("[]".utf8)
        activeModIDsData = String(decoding: data, as: UTF8.self)
    }

    private func refresh() {
        let path = NSString(string: installationPath).expandingTildeInPath
        let installation = path.isEmpty ? nil : URL(fileURLWithPath: path).standardizedFileURL
        mods = FreeColMod.discover(installation: installation)
    }

    private func chooseInstallation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            installationPath = url.path
        }
    }
}
