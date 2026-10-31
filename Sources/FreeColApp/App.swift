import SwiftUI
import FreeColClient
#if canImport(AppKit)
import AppKit
#endif

@main
struct FreeColApp: App {
    @State private var gameState = GameState()

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
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FreeColClient") {
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
                string: "Open-source macOS client for the FreeCol turn-based strategy game.\nhttps://github.com/Copilot/FreeColClient",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
#endif
    }
}
