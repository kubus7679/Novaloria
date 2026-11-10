import SwiftUI
import NovaloriaClient
#if canImport(AppKit)
import AppKit

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private static var originalMenuTitles: [ObjectIdentifier: String] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let iconURL = Bundle.module.url(forResource: "novaloria-app-icon", withExtension: "svg"),
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

    static func refreshMenuBarLocalization() {
        DispatchQueue.main.async {
            configureMenuBar()
        }
    }

    private static func configureMenuBar() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // Fold the remaining standard File commands (typically Close Window)
        // into the game menu; saving is exposed there as well.
        let fileMenuIndex = mainMenu.items.firstIndex {
            ["file", "datei", "ablage", "archivo"].contains(normalizedMenuTitle($0.title))
        }
        let gameMenuTitles = ["Spiel", "Game", "Partida", "Juego"].map(normalizedMenuTitle)
        let gameMenuItem = mainMenu.items.first { gameMenuTitles.contains(normalizedMenuTitle($0.title)) }
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
            "file": L10n.text("Datei", table: "App"), "datei": L10n.text("Datei", table: "App"),
            "ablage": L10n.text("Datei", table: "App"), "archivo": L10n.text("Datei", table: "App"),
            "edit": L10n.text("Bearbeiten", table: "App"), "bearbeiten": L10n.text("Bearbeiten", table: "App"),
            "editar": L10n.text("Bearbeiten", table: "App"), "edición": L10n.text("Bearbeiten", table: "App"),
            "view": L10n.text("Ansicht", table: "App"), "ansicht": L10n.text("Ansicht", table: "App"),
            "darstellung": L10n.text("Ansicht", table: "App"), "visualización": L10n.text("Ansicht", table: "App"),
            "window": L10n.text("Fenster", table: "App"), "fenster": L10n.text("Fenster", table: "App"),
            "ventana": L10n.text("Fenster", table: "App"),
            "help": L10n.text("Hilfe", table: "App"), "hilfe": L10n.text("Hilfe", table: "App"),
            "ayuda": L10n.text("Hilfe", table: "App"),
            "spiel": L10n.text("Spiel", table: "App"),
            "game": L10n.text("Spiel", table: "App"),
            "partida": L10n.text("Spiel", table: "App"),
            "juego": L10n.text("Spiel", table: "App"),
            "befehle": L10n.text("Befehle", table: "App"),
            "orders": L10n.text("Befehle", table: "App"),
            "órdenes": L10n.text("Befehle", table: "App"),
            "berichte": L10n.text("Berichte", table: "App"),
            "reports": L10n.text("Berichte", table: "App"),
            "informes": L10n.text("Berichte", table: "App"),
            "colopädie": L10n.text("Colopädie", table: "App"),
            "colopedia": L10n.text("Colopädie", table: "App"),
        ]
        for item in mainMenu.items {
            if let localized = menuTitles[normalizedMenuTitle(originalTitle(for: item))] {
                item.title = localized
            }
            if let submenu = item.submenu {
                localize(submenu)
            }
        }
    }

    private static func localize(_ menu: NSMenu) {
        let titles = [
            "undo": L10n.text("Rückgängig", table: "App"), "redo": L10n.text("Wiederholen", table: "App"),
            "cut": L10n.text("Ausschneiden", table: "App"), "copy": L10n.text("Kopieren", table: "App"),
            "paste": L10n.text("Einsetzen", table: "App"),
            "paste and match style": L10n.text("Einsetzen und Stil anpassen", table: "App"),
            "delete": L10n.text("Löschen", table: "App"), "select all": L10n.text("Alles auswählen", table: "App"),
            "find": L10n.text("Suchen", table: "App"), "find...": L10n.text("Suchen…", table: "App"),
            "find next": L10n.text("Weitersuchen", table: "App"),
            "find previous": L10n.text("Rückwärts suchen", table: "App"),
            "find and replace...": L10n.text("Suchen und Ersetzen…", table: "App"),
            "use selection for find": L10n.text("Auswahl zum Suchen verwenden", table: "App"),
            "jump to selection": L10n.text("Zur Auswahl springen", table: "App"),
            "spelling and grammar": L10n.text("Rechtschreibung und Grammatik", table: "App"),
            "show spelling and grammar": L10n.text("Rechtschreibung und Grammatik einblenden", table: "App"),
            "check document now": L10n.text("Dokument jetzt prüfen", table: "App"),
            "check spelling while typing": L10n.text("Rechtschreibung während der Eingabe prüfen", table: "App"),
            "check grammar with spelling": L10n.text("Grammatik mit Rechtschreibung prüfen", table: "App"),
            "correct spelling automatically": L10n.text("Rechtschreibung automatisch korrigieren", table: "App"),
            "autofill": L10n.text("Automatisch ausfüllen", table: "App"),
            "substitutions": L10n.text("Ersetzungen", table: "App"),
            "transformations": L10n.text("Umwandlungen", table: "App"),
            "speech": L10n.text("Sprachausgabe", table: "App"),
            "start speaking": L10n.text("Sprechen beginnen", table: "App"),
            "stop speaking": L10n.text("Sprechen beenden", table: "App"),
            "start dictation": L10n.text("Diktat starten", table: "App"),
            "emoji & symbols": L10n.text("Emojis und Symbole", table: "App"),
            "show toolbar": L10n.text("Symbolleiste einblenden", table: "App"),
            "hide toolbar": L10n.text("Symbolleiste ausblenden", table: "App"),
            "customize toolbar...": L10n.text("Symbolleiste anpassen…", table: "App"),
            "enter full screen": L10n.text("Vollbild starten", table: "App"),
            "exit full screen": L10n.text("Vollbild beenden", table: "App"),
            "show tab bar": L10n.text("Tableiste einblenden", table: "App"),
            "hide tab bar": L10n.text("Tableiste ausblenden", table: "App"),
            "show sidebar": L10n.text("Seitenleiste einblenden", table: "App"),
            "hide sidebar": L10n.text("Seitenleiste ausblenden", table: "App"),
            "minimize": L10n.text("Minimieren", table: "App"), "zoom": L10n.text("Zoomen", table: "App"),
            "bring all to front": L10n.text("Alle Fenster nach vorne", table: "App"),
            "show previous tab": L10n.text("Vorheriger Tab", table: "App"),
            "show next tab": L10n.text("Nächster Tab", table: "App"),
            "move tab to new window": L10n.text("Tab in neues Fenster verschieben", table: "App"),
            "merge all windows": L10n.text("Alle Fenster zusammenführen", table: "App"),
            "move & resize": L10n.text("Fenster verschieben und Größe ändern", table: "App"),
            "tile window to left of screen": L10n.text("Fenster links anordnen", table: "App"),
            "tile window to right of screen": L10n.text("Fenster rechts anordnen", table: "App"),
            "move window to left side of screen": L10n.text("Fenster an den linken Bildschirmrand bewegen", table: "App"),
            "move window to right side of screen": L10n.text("Fenster an den rechten Bildschirmrand bewegen", table: "App"),
            "services": L10n.text("Dienste", table: "App"),
            "settings...": L10n.text("Einstellungen…", table: "App"),
            "preferences...": L10n.text("Einstellungen…", table: "App"),
            "hide others": L10n.text("Andere ausblenden", table: "App"),
            "show all": L10n.text("Alle einblenden", table: "App"),
            "search": L10n.text("Suchen", table: "App"),
            "search help": L10n.text("Hilfe durchsuchen", table: "App"),
            "close window": L10n.text("Fenster schließen", table: "App"),
            "close": L10n.text("Schließen", table: "App"),
            "new window": L10n.text("Neues Fenster", table: "App"),
        ]

        for item in menu.items {
            let title = normalizedMenuTitle(originalTitle(for: item))
            if let localized = titles[title] {
                item.title = localized
            } else if title.hasPrefix("about ") {
                item.title = L10n.text("Über Novaloria", table: "App")
            } else if title.hasPrefix("hide ") {
                item.title = L10n.text("Novaloria ausblenden", table: "App")
            } else if title.hasPrefix("quit ") {
                item.title = L10n.text("Beenden", table: "App")
            } else if title.hasPrefix("close ") {
                item.title = L10n.text("Fenster schließen", table: "App")
            } else if title.hasSuffix(" help") {
                item.title = L10n.text("Novaloria-Hilfe", table: "App")
            }

            if let submenu = item.submenu {
                localize(submenu)
            }
        }
    }

    private static func originalTitle(for item: NSMenuItem) -> String {
        let identifier = ObjectIdentifier(item)
        if let title = originalMenuTitles[identifier] { return title }
        originalMenuTitles[identifier] = item.title
        return item.title
    }

    private static func normalizedMenuTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "...")
            .lowercased()
    }
}
#endif

@main
struct Novaloria: App {
    @State private var gameState = GameState()
    @AppStorage(InterfaceLanguage.preferenceKey) private var interfaceLanguage = InterfaceLanguage.system.rawValue
#if canImport(AppKit)
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
#endif

    var body: some Scene {
        WindowGroup {
            let language = InterfaceLanguage(rawValue: interfaceLanguage) ?? .system
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
            .environment(LocalizationSettings.shared)
            .environment(\.locale, language.locale)
            .frame(minWidth: gameState.phase == .inGame || gameState.phase == .reconnecting ? 900 : 520,
                   minHeight: 620)
            .onAppear {
                LocalizationSettings.shared.language = language
                #if canImport(AppKit)
                ApplicationDelegate.refreshMenuBarLocalization()
                #endif
                if CommandLine.arguments.contains("--auto-local-game"), gameState.phase == .disconnected {
                    gameState.startLocal(userName: "Alice", nationId: "model.nation.dutch")
                }
            }
            .onChange(of: interfaceLanguage) { _, value in
                let selected = InterfaceLanguage(rawValue: value) ?? .system
                LocalizationSettings.shared.language = selected
                #if canImport(AppKit)
                ApplicationDelegate.refreshMenuBarLocalization()
                #endif
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
                Button(L10n.text("Über Novaloria", table: "App")) {
                    showAboutPanel()
                }
            }
        }
    }

    private func showAboutPanel() {
#if canImport(AppKit)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Novaloria",
            .applicationVersion: AppVersion.version,
            .credits: NSAttributedString(
                string: L10n.text(
                    "Inoffizieller Open-Source-macOS-Client für FreeCol.",
                    table: "App"
                ) + "\nhttps://github.com/kubus7679/Novaloria",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
#endif
    }
}
