//
//  KeyboardShortcutsView.swift
//  FreeColClient
//
//  Displays the available keyboard shortcuts in a help panel.
//

import SwiftUI

/// View that displays all available keyboard shortcuts
struct KeyboardShortcutsView: View {
    @Environment(GameState.self) private var state
    @State private var searchText: String = ""
    
    private var manager: KeyboardShortcutsManager? {
        // The manager should be accessible through GameState
        // For now, we'll create a temporary one or access it from state
        // In the final implementation, GameState should have the manager
        return nil
    }
    
    // Mock data for preview
    private var shortcuts: [KeyboardShortcut] {
        [
            // Unit shortcuts
            KeyboardShortcut(key: "b", modifier: .none, action: {}, description: "Kolonie bauen", category: .unit),
            KeyboardShortcut(key: "r", modifier: .none, action: {}, description: "Straße bauen", category: .unit),
            KeyboardShortcut(key: "w", modifier: .none, action: {}, description: "Warten / Überspringen", category: .unit),
            KeyboardShortcut(key: "s", modifier: .none, action: {}, description: "Wache halten", category: .unit),
            KeyboardShortcut(key: "f", modifier: .none, action: {}, description: "Befestigen", category: .unit),
            KeyboardShortcut(key: "a", modifier: .none, action: {}, description: "Einheit aktivieren", category: .unit),
            KeyboardShortcut(key: "e", modifier: .none, action: {}, description: "Einheit auflösen", category: .unit),
            KeyboardShortcut(key: "n", modifier: .none, action: {}, description: "Nächste Einheit auswählen", category: .unit),
            KeyboardShortcut(key: "p", modifier: .none, action: {}, description: "Vorherige Einheit auswählen", category: .unit),
            KeyboardShortcut(key: "c", modifier: .shift, action: {}, description: "Befehle löschen", category: .unit),
            KeyboardShortcut(key: "i", modifier: .none, action: {}, description: "An Bord gehen", category: .unit),
            KeyboardShortcut(key: "o", modifier: .none, action: {}, description: "Von Bord gehen", category: .unit),
            KeyboardShortcut(key: "t", modifier: .none, action: {}, description: "Nahkampf", category: .unit),
            KeyboardShortcut(key: "t", modifier: .shift, action: {}, description: "Fernkampf", category: .unit),
            
            // Colony shortcuts
            KeyboardShortcut(key: "c", modifier: .none, action: {}, description: "Kolonie-Panel öffnen", category: .colony),
            KeyboardShortcut(key: "j", modifier: .none, action: {}, description: "In der Kolonie arbeiten", category: .colony),
            
            // Map shortcuts
            KeyboardShortcut(key: "u", modifier: .none, action: {}, description: "Karte auf ausgewählte Einheit zentrieren", category: .map),
            KeyboardShortcut(key: "l", modifier: .none, action: {}, description: "Siedlung suchen", category: .map),
            KeyboardShortcut(key: "f", modifier: .shift, action: {}, description: "Nebel des Krieges umschalten", category: .map),
            KeyboardShortcut(key: "g", modifier: .shift, action: {}, description: "Gitter anzeigen/verstecken", category: .map),
            KeyboardShortcut(key: "b", modifier: .shift, action: {}, description: "Grenzen anzeigen/verstecken", category: .map),
            KeyboardShortcut(key: "up", modifier: .none, action: {}, description: "Karte nach oben scrollen", category: .map),
            KeyboardShortcut(key: "down", modifier: .none, action: {}, description: "Karte nach unten scrollen", category: .map),
            KeyboardShortcut(key: "left", modifier: .none, action: {}, description: "Karte nach links scrollen", category: .map),
            KeyboardShortcut(key: "right", modifier: .none, action: {}, description: "Karte nach rechts scrollen", category: .map),
            
            // Game shortcuts
            KeyboardShortcut(key: "enter", modifier: .control, action: {}, description: "Zug beenden", category: .game),
            KeyboardShortcut(key: "s", modifier: .command, action: {}, description: "Spiel speichern", category: .game),
            KeyboardShortcut(key: "e", modifier: .shift, action: {}, description: "Europa-Panel öffnen", category: .game),
            KeyboardShortcut(key: "r", modifier: .command, action: {}, description: "Berichte öffnen", category: .game),
            KeyboardShortcut(key: "c", modifier: .command, action: {}, description: "Chat öffnen", category: .game),
            
            // View shortcuts
            KeyboardShortcut(key: "/", modifier: .shift, action: {}, description: "Tastaturkürzel anzeigen/verstecken", category: .view),
            KeyboardShortcut(key: "+", modifier: .none, action: {}, description: "Hineinzoomen", category: .view),
            KeyboardShortcut(key: "-", modifier: .none, action: {}, description: "Herauszoomen", category: .view),
            KeyboardShortcut(key: "0", modifier: .none, action: {}, description: "Zoom zurücksetzen", category: .view),
            KeyboardShortcut(key: "d", modifier: .command, action: {}, description: "Debug-Panel öffnen", category: .view),
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tastaturkürzel")
                    .font(.title2.bold())
                Spacer()
                Button("Schließen") {
                    state.showShortcutsHelp = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            
            Divider()
            
            // Search field
            TextField("Suchen...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(KeyboardShortcut.ShortcutCategory.allCases, id: \.self) { category in
                        let categoryShortcuts = shortcuts
                            .filter { $0.category == category }
                            .filter { searchText.isEmpty || $0.description.localizedCaseInsensitiveContains(searchText) }
                        
                        if categoryShortcuts.isEmpty {
                            EmptyView()
                        } else {
                            shortcutCategoryView(category: category, shortcuts: categoryShortcuts)
                        }
                    }
                }
                .padding(12)
            }
            
            // Footer with hint
            Divider()
            HStack {
                Text("Tip: \(KeyboardShortcut(key: "/", modifier: .shift, action: {}, description: "", category: .view).fullDisplay) - Tastaturkürzel anzeigen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 800,
               minHeight: 400, idealHeight: 500, maxHeight: 600)
    }
    
    @ViewBuilder
    private func shortcutCategoryView(category: KeyboardShortcut.ShortcutCategory, shortcuts: [KeyboardShortcut]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 4)
            
            ForEach(shortcuts) { shortcut in
                shortcutRow(shortcut: shortcut)
            }
        }
    }
    
    @ViewBuilder
    private func shortcutRow(shortcut: KeyboardShortcut) -> some View {
        HStack(spacing: 12) {
            // Key combination
            Text(shortcut.fullDisplay)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                )
            
            // Description
            Text(shortcut.description)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutsView()
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
}
