import SwiftUI
import FreeColClient
#if canImport(AppKit)
import AppKit

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let iconURL = Bundle.module.url(forResource: "freecol-app-icon", withExtension: "svg"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.activate()
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            Self.configureMenuBar()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.async {
            Self.configureMenuBar()
        }
    }

    private static func configureMenuBar() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // Fold the remaining standard File commands (typically Close Window)
        // into the game menu; saving is exposed there as well.
        let fileMenuIndex = mainMenu.items.firstIndex {
            ["file", "datei", "ablage"].contains(normalizedMenuTitle($0.title))
        }
        let gameMenuItem = mainMenu.items.first {
            normalizedMenuTitle($0.title) == "spiel"
        }
        if let fileMenuIndex,
           let fileMenu = mainMenu.items[fileMenuIndex].submenu,
           let gameMenu = gameMenuItem?.submenu {
            if !fileMenu.items.isEmpty {
                if !gameMenu.items.isEmpty, !gameMenu.items.last!.isSeparatorItem {
                    gameMenu.addItem(.separator())
                }
                for item in fileMenu.items {
                    guard let copy = item.copy() as? NSMenuItem else { continue }
                    gameMenu.addItem(copy)
                }
            }
            mainMenu.removeItem(at: fileMenuIndex)
        }

        let menuTitles = [
            "file": "Datei", "datei": "Datei", "ablage": "Datei",
            "edit": "Bearbeiten", "bearbeiten": "Bearbeiten",
            "view": "Ansicht", "ansicht": "Ansicht", "darstellung": "Ansicht",
            "window": "Fenster", "fenster": "Fenster",
            "help": "Hilfe", "hilfe": "Hilfe",
        ]
        for item in mainMenu.items {
            if let localized = menuTitles[normalizedMenuTitle(item.title)] {
                item.title = localized
            }
            if let submenu = item.submenu {
                localize(submenu)
            }
        }
    }

    private static func localize(_ menu: NSMenu) {
        let titles = [
            "undo": "Rückgängig", "redo": "Wiederholen",
            "cut": "Ausschneiden", "copy": "Kopieren", "paste": "Einsetzen",
            "paste and match style": "Einsetzen und Stil anpassen",
            "delete": "Löschen", "select all": "Alles auswählen",
            "find": "Suchen", "find...": "Suchen…", "find next": "Weitersuchen",
            "find previous": "Rückwärts suchen", "find and replace...": "Suchen und Ersetzen…",
            "use selection for find": "Auswahl zum Suchen verwenden",
            "jump to selection": "Zur Auswahl springen",
            "spelling and grammar": "Rechtschreibung und Grammatik",
            "show spelling and grammar": "Rechtschreibung und Grammatik einblenden",
            "check document now": "Dokument jetzt prüfen",
            "check spelling while typing": "Rechtschreibung während der Eingabe prüfen",
            "check grammar with spelling": "Grammatik mit Rechtschreibung prüfen",
            "correct spelling automatically": "Rechtschreibung automatisch korrigieren",
            "autofill": "Automatisch ausfüllen",
            "substitutions": "Ersetzungen", "transformations": "Umwandlungen",
            "speech": "Sprachausgabe", "start speaking": "Sprechen beginnen",
            "stop speaking": "Sprechen beenden", "start dictation": "Diktat starten",
            "emoji & symbols": "Emojis und Symbole",
            "show toolbar": "Symbolleiste einblenden", "hide toolbar": "Symbolleiste ausblenden",
            "customize toolbar...": "Symbolleiste anpassen…",
            "enter full screen": "Vollbild starten", "exit full screen": "Vollbild beenden",
            "show tab bar": "Tableiste einblenden", "hide tab bar": "Tableiste ausblenden",
            "show sidebar": "Seitenleiste einblenden", "hide sidebar": "Seitenleiste ausblenden",
            "minimize": "Minimieren", "zoom": "Zoomen",
            "bring all to front": "Alle Fenster nach vorne",
            "show previous tab": "Vorheriger Tab", "show next tab": "Nächster Tab",
            "move tab to new window": "Tab in neues Fenster verschieben",
            "merge all windows": "Alle Fenster zusammenführen",
            "move & resize": "Fenster verschieben und Größe ändern",
            "tile window to left of screen": "Fenster links anordnen",
            "tile window to right of screen": "Fenster rechts anordnen",
            "move window to left side of screen": "Fenster an den linken Bildschirmrand bewegen",
            "move window to right side of screen": "Fenster an den rechten Bildschirmrand bewegen",
            "services": "Dienste", "settings...": "Einstellungen…",
            "preferences...": "Einstellungen…", "hide others": "Andere ausblenden",
            "show all": "Alle einblenden", "search": "Suchen", "search help": "Hilfe durchsuchen",
            "close window": "Fenster schließen", "close": "Schließen",
            "new window": "Neues Fenster",
        ]

        for item in menu.items {
            let title = normalizedMenuTitle(item.title)
            if let localized = titles[title] {
                item.title = localized
            } else if title.hasPrefix("about ") {
                item.title = "Über FreeColClient"
            } else if title.hasPrefix("hide ") {
                item.title = "FreeColClient ausblenden"
            } else if title.hasPrefix("quit ") {
                item.title = "Beenden"
            } else if title.hasPrefix("close ") {
                item.title = "Fenster schließen"
            } else if title.hasSuffix(" help") {
                item.title = "FreeColClient-Hilfe"
            }

            if let submenu = item.submenu {
                localize(submenu)
            }
        }
    }

    private static func normalizedMenuTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "...")
            .lowercased()
    }
}
#endif

@main
struct FreeColApp: App {
    @State private var gameState = GameState()
#if canImport(AppKit)
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
#endif

    var body: some Scene {
        WindowGroup {
            Group {
                switch gameState.phase {
                case .disconnected, .connecting:
                    LoginView()
                case .login, .lobby:
                    LoginView()
                case .inGame, .reconnecting:
                    GameView()
                }
            }
            .environment(gameState)
            .frame(minWidth: gameState.phase == .inGame || gameState.phase == .reconnecting ? 900 : 520,
                   minHeight: 620)
            .onAppear {
                if CommandLine.arguments.contains("--auto-local-game"), gameState.phase == .disconnected {
                    gameState.startLocal(userName: "Alice", nationId: "model.nation.dutch")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                gameState.stopHostedServer()
            }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            GameCommands(state: gameState)
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .importExport) { }
            CommandGroup(replacing: .printItem) { }
            CommandGroup(replacing: .appSettings) { }
            CommandGroup(replacing: .appInfo) {
                Button("Über FreeColClient") {
                    showAboutPanel()
                }
            }
        }
    }

    private func showAboutPanel() {
#if canImport(AppKit)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "FreeColClient",
            .applicationVersion: AppVersion.version,
            .version: AppVersion.gitHash,
            .credits: NSAttributedString(
                string: "Open-Source-macOS-Client für das FreeCol-Rundenstrategiespiel.\nhttps://github.com/Copilot/FreeColClient",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
#endif
    }
}
