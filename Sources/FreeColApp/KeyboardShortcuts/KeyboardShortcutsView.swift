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
        state.keyboardShortcutsManager
    }

    private var shortcuts: [KeyboardShortcut] {
        manager?.registeredShortcuts ?? []
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

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("„Verfügbar“ zeigt an, ob das Kürzel im aktuellen Spielzustand nutzbar ist.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
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
                Text("Tipp: ⇧/ – Tastaturkürzel anzeigen")
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

            let isAvailable = manager?.isShortcutEnabled(shortcut) == true
            Text(isAvailable ? "Verfügbar" : "Nicht verfügbar")
                .font(.caption)
                .foregroundStyle(isAvailable ? .green : .secondary)
                .frame(width: 105, alignment: .trailing)
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
