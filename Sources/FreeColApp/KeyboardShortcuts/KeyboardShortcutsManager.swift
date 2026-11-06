//
//  KeyboardShortcutsManager.swift
//  FreeColClient
//
//  Manages keyboard shortcuts for the game, similar to the Java FreeCol client.
//

import SwiftUI
import FreeColGame

/// Represents a keyboard shortcut with its key, modifier, action, and description
struct KeyboardShortcut: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let modifier: KeyModifier
    let action: () -> Void
    let description: String
    let category: ShortcutCategory
    
    enum KeyModifier: String, CaseIterable {
        case none = ""
        case command = "⌘"
        case shift = "⇧"
        case option = "⌥"
        case control = "⌃"
        case commandShift = "⌘⇧"
        case commandOption = "⌘⌥"
    }
    
    enum ShortcutCategory: String, CaseIterable {
        case unit = "Einheit"
        case colony = "Kolonie"
        case map = "Karte"
        case game = "Spiel"
        case view = "Ansicht"
        
        var displayName: String {
            rawValue
        }
    }
    
    var displayKey: String {
        var result = key
        // Handle special keys
        switch key.lowercased() {
        case "space": result = "Space"
        case "enter", "return": result = "Enter"
        case "delete": result = "Delete"
        case "escape": result = "Esc"
        case "up": result = "↑"
        case "down": result = "↓"
        case "left": result = "←"
        case "right": result = "→"
        case "plus", "=" : result = "+"
        case "minus": result = "-"
        default: break
        }
        return result
    }
    
    var fullDisplay: String {
        let modifierText = modifier.rawValue
        return modifierText.isEmpty ? displayKey : "\(modifierText)\(displayKey)"
    }
    
    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages keyboard shortcuts for the FreeCol game
@MainActor
@Observable
final class KeyboardShortcutsManager {
    
    // All registered shortcuts
    private(set) var shortcuts: [KeyboardShortcut] = []
    
    // Shortcuts grouped by category for display
    var shortcutsByCategory: [KeyboardShortcut.ShortcutCategory: [KeyboardShortcut]] {
        Dictionary(grouping: shortcuts, by: { $0.category })
    }
    
    // Reference to the game state
    weak var gameState: GameState?
    
    init(gameState: GameState? = nil) {
        self.gameState = gameState
        registerDefaultShortcuts()
    }
    
    func setGameState(_ gameState: GameState) {
        self.gameState = gameState
        // Re-register shortcuts with the new game state
        shortcuts.removeAll()
        registerDefaultShortcuts()
    }
    
    /// Register all default keyboard shortcuts
    private func registerDefaultShortcuts() {
        // Unit action shortcuts
        registerUnitShortcuts()
        
        // Colony shortcuts
        registerColonyShortcuts()
        
        // Map shortcuts
        registerMapShortcuts()
        
        // Game shortcuts
        registerGameShortcuts()
        
        // View shortcuts
        registerViewShortcuts()
    }
    
    /// Register unit-related keyboard shortcuts
    private func registerUnitShortcuts() {
        guard let state = gameState else { return }
        
        // Build colony - b
        shortcuts.append(KeyboardShortcut(
            key: "b",
            modifier: .none,
            action: { state.attemptBuildColonyWithShortcut() },
            description: "Kolonie bauen",
            category: .unit
        ))
        
        // Build road - r
        shortcuts.append(KeyboardShortcut(
            key: "r",
            modifier: .none,
            action: { state.attemptBuildRoadWithShortcut() },
            description: "Straße bauen",
            category: .unit
        ))
        
        // Wait/Skip - w
        shortcuts.append(KeyboardShortcut(
            key: "w",
            modifier: .none,
            action: { state.setSelectedUnitState(.skipped) },
            description: "Warten / Überspringen",
            category: .unit
        ))
        
        // Sentry - s
        shortcuts.append(KeyboardShortcut(
            key: "s",
            modifier: .none,
            action: { state.setSelectedUnitState(.sentry) },
            description: "Wache halten",
            category: .unit
        ))
        
        // Fortify - f
        shortcuts.append(KeyboardShortcut(
            key: "f",
            modifier: .none,
            action: { state.setSelectedUnitState(.fortifying) },
            description: "Befestigen",
            category: .unit
        ))
        
        // Disband unit - e (like "end" unit)
        shortcuts.append(KeyboardShortcut(
            key: "e",
            modifier: .none,
            action: { state.disbandSelectedUnit() },
            description: "Einheit auflösen",
            category: .unit
        ))
        
        // Next unit - n
        shortcuts.append(KeyboardShortcut(
            key: "n",
            modifier: .none,
            action: { state.selectNextUnit() },
            description: "Nächste Einheit auswählen",
            category: .unit
        ))
        
        // Previous unit - p
        shortcuts.append(KeyboardShortcut(
            key: "p",
            modifier: .none,
            action: { state.selectPreviousUnit() },
            description: "Vorherige Einheit auswählen",
            category: .unit
        ))
        
        // Activate unit - a
        shortcuts.append(KeyboardShortcut(
            key: "a",
            modifier: .none,
            action: { state.setSelectedUnitState(.active) },
            description: "Einheit aktivieren",
            category: .unit
        ))
        
        // Clear orders - c (when unit is selected, not for colony)
        shortcuts.append(KeyboardShortcut(
            key: "c",
            modifier: .shift,
            action: { state.clearSelectedUnitOrders() },
            description: "Befehle löschen",
            category: .unit
        ))
        
        // Embark on carrier
        shortcuts.append(KeyboardShortcut(
            key: "i",
            modifier: .none,
            action: { state.embarkSelectedUnitOnDefaultCarrier() },
            description: "An Bord gehen",
            category: .unit
        ))
        
        // Disembark from carrier
        shortcuts.append(KeyboardShortcut(
            key: "o",
            modifier: .none,
            action: { state.disembarkSelectedUnit() },
            description: "Von Bord gehen",
            category: .unit
        ))
        
        // Attack - t (melee)
        shortcuts.append(KeyboardShortcut(
            key: "t",
            modifier: .none,
            action: { state.attemptAttackWithShortcut(ranged: false) },
            description: "Nahkampf",
            category: .unit
        ))
        
        // Ranged attack - T (shift + t)
        shortcuts.append(KeyboardShortcut(
            key: "t",
            modifier: .shift,
            action: { state.attemptAttackWithShortcut(ranged: true) },
            description: "Fernkampf",
            category: .unit
        ))
    }
    
    /// Register colony-related keyboard shortcuts
    private func registerColonyShortcuts() {
        guard let state = gameState else { return }
        
        // Open colony panel - c
        shortcuts.append(KeyboardShortcut(
            key: "c",
            modifier: .none,
            action: { state.openColonyPanel() },
            description: "Kolonie-Panel öffnen",
            category: .colony
        ))
        
        // Join colony - j
        shortcuts.append(KeyboardShortcut(
            key: "j",
            modifier: .none,
            action: { state.joinSelectedColony() },
            description: "In der Kolonie arbeiten",
            category: .colony
        ))
    }
    
    /// Register map-related keyboard shortcuts
    private func registerMapShortcuts() {
        guard let state = gameState else { return }
        
        // Center on selected unit - u
        shortcuts.append(KeyboardShortcut(
            key: "u",
            modifier: .none,
            action: { state.centerMapOnSelectedUnit() },
            description: "Karte auf ausgewählte Einheit zentrieren",
            category: .map
        ))
        
        // Find settlement - l
        shortcuts.append(KeyboardShortcut(
            key: "l",
            modifier: .none,
            action: { state.toggleFindSettlement() },
            description: "Siedlung suchen",
            category: .map
        ))
        
        // Toggle fog of war - F
        shortcuts.append(KeyboardShortcut(
            key: "f",
            modifier: .shift,
            action: { state.toggleFogOfWar() },
            description: "Nebel des Krieges umschalten",
            category: .map
        ))
        
        // Toggle grid - G
        shortcuts.append(KeyboardShortcut(
            key: "g",
            modifier: .shift,
            action: { state.toggleMapGrid() },
            description: "Gitter anzeigen/verstecken",
            category: .map
        ))
        
        // Toggle borders - B
        shortcuts.append(KeyboardShortcut(
            key: "b",
            modifier: .shift,
            action: { state.toggleBorders() },
            description: "Grenzen anzeigen/verstecken",
            category: .map
        ))
        
        // Arrow keys for map movement
        shortcuts.append(KeyboardShortcut(
            key: "up",
            modifier: .none,
            action: { self.scrollMap(direction: .up) },
            description: "Karte nach oben scrollen",
            category: .map
        ))
        
        shortcuts.append(KeyboardShortcut(
            key: "down",
            modifier: .none,
            action: { self.scrollMap(direction: .down) },
            description: "Karte nach unten scrollen",
            category: .map
        ))
        
        shortcuts.append(KeyboardShortcut(
            key: "left",
            modifier: .none,
            action: { self.scrollMap(direction: .left) },
            description: "Karte nach links scrollen",
            category: .map
        ))
        
        shortcuts.append(KeyboardShortcut(
            key: "right",
            modifier: .none,
            action: { self.scrollMap(direction: .right) },
            description: "Karte nach rechts scrollen",
            category: .map
        ))
    }
    
    /// Register game-related keyboard shortcuts
    private func registerGameShortcuts() {
        guard let state = gameState else { return }
        
        // End turn - t (but t is used for attack, so use T or other)
        // Using Ctrl+Enter for end turn to avoid conflicts
        shortcuts.append(KeyboardShortcut(
            key: "enter",
            modifier: .control,
            action: { state.requestEndTurn() },
            description: "Zug beenden",
            category: .game
        ))
        
        // Save game - S
        shortcuts.append(KeyboardShortcut(
            key: "s",
            modifier: .command,
            action: { state.showSaveGamePanel() },
            description: "Spiel speichern",
            category: .game
        ))
        
        // Europe panel - E
        shortcuts.append(KeyboardShortcut(
            key: "e",
            modifier: .shift,
            action: { state.openEuropePanel() },
            description: "Europa-Panel öffnen",
            category: .game
        ))
        
        // Reports - R
        shortcuts.append(KeyboardShortcut(
            key: "r",
            modifier: .command,
            action: { self.showReports() },
            description: "Berichte öffnen",
            category: .game
        ))
        
        // Chat - C
        shortcuts.append(KeyboardShortcut(
            key: "c",
            modifier: .command,
            action: { self.showChat() },
            description: "Chat öffnen",
            category: .game
        ))
    }
    
    /// Register view-related keyboard shortcuts
    private func registerViewShortcuts() {
        guard let state = gameState else { return }
        
        // Toggle shortcuts help - ?
        shortcuts.append(KeyboardShortcut(
            key: "/",
            modifier: .shift,
            action: { self.toggleShortcutsHelp() },
            description: "Tastaturkürzel anzeigen/verstecken",
            category: .view
        ))
        
        // Zoom in - +
        shortcuts.append(KeyboardShortcut(
            key: "+",
            modifier: .none,
            action: { self.zoomMap(in: true) },
            description: "Hineinzoomen",
            category: .view
        ))
        
        // Zoom out - -
        shortcuts.append(KeyboardShortcut(
            key: "-",
            modifier: .none,
            action: { self.zoomMap(in: false) },
            description: "Herauszoomen",
            category: .view
        ))
        
        // Reset zoom - 0
        shortcuts.append(KeyboardShortcut(
            key: "0",
            modifier: .none,
            action: { self.resetMapZoom() },
            description: "Zoom zurücksetzen",
            category: .view
        ))
        
        // Debug panel - D
        shortcuts.append(KeyboardShortcut(
            key: "d",
            modifier: .command,
            action: { state.openDebugPanel() },
            description: "Debug-Panel öffnen",
            category: .view
        ))
    }
    
    /// Get shortcut for a specific key combination
    func shortcut(for key: String, modifier: KeyboardShortcut.KeyModifier) -> KeyboardShortcut? {
        shortcuts.first { 
            $0.key.lowercased() == key.lowercased() && $0.modifier == modifier
        }
    }
    
    /// Execute shortcut action for a key press
    func handleKeyPress(_ key: String, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        let modifier = parseModifierFlags(modifierFlags)
        
        // Try exact match first
        if let shortcut = shortcut(for: key, modifier: modifier) {
            guard isShortcutEnabled(shortcut) else { return false }
            shortcut.action()
            return true
        }
        
        // Try without modifier if no exact match
        if modifier == .none, let shortcut = shortcut(for: key, modifier: .none) {
            guard isShortcutEnabled(shortcut) else { return false }
            shortcut.action()
            return true
        }
        
        return false
    }
    
    /// Parse NSEvent modifier flags into our KeyModifier enum
    private func parseModifierFlags(_ flags: NSEvent.ModifierFlags) -> KeyboardShortcut.KeyModifier {
        var modifier: KeyboardShortcut.KeyModifier = .none
        
        if flags.contains(.command) {
            if flags.contains(.shift) {
                modifier = .commandShift
            } else if flags.contains(.option) {
                modifier = .commandOption
            } else {
                modifier = .command
            }
        } else if flags.contains(.shift) {
            modifier = .shift
        } else if flags.contains(.option) {
            modifier = .option
        } else if flags.contains(.control) {
            modifier = .control
        }
        
        return modifier
    }
    
    /// All registered shortcuts, including those unavailable in the current context.
    var registeredShortcuts: [KeyboardShortcut] {
        shortcuts
    }

    /// Get shortcuts that are currently enabled based on the game state.
    var availableShortcuts: [KeyboardShortcut] {
        shortcuts.filter(isShortcutEnabled)
    }
    
    /// Check if a shortcut is currently enabled based on game state
    func isShortcutEnabled(_ shortcut: KeyboardShortcut) -> Bool {
        guard let state = gameState, state.pendingServerDecision == nil else { return false }
        
        // Check based on shortcut description/action type
        switch (shortcut.category, shortcut.description) {
        case (.unit, _):
            // Unit shortcuts need a selected unit
            return state.selectedUnit != nil
            
        case (.colony, _):
            // Colony shortcuts need a selected colony
            return state.selectedColony != nil
            
        case (.game, let desc) where desc.contains("speichern"):
            return state.canSaveGame
            
        case (.game, let desc) where desc.contains("Zug beenden"):
            return state.canEndTurn
            
        default:
            return true
        }
    }
    
    // MARK: - Map Scrolling Support
    
    /// Scroll map in a direction
    enum ScrollDirection {
        case up, down, left, right
    }
    
    func scrollMap(direction: ScrollDirection) {
        // This would need implementation to scroll the map
        // For now, just a placeholder
        gameState?.statusMessage = "Karte scrollen: \(direction)"
    }
    
    /// Zoom map in/out
    func zoomMap(in zoomIn: Bool) {
        gameState?.zoomMap(in: zoomIn)
    }
    
    /// Reset map zoom to default
    func resetMapZoom() {
        gameState?.resetMapZoom()
    }
    
    /// Show reports panel
    func showReports() {
        gameState?.showReports()
    }
    
    /// Show chat panel
    func showChat() {
        gameState?.showChat()
    }
    
    /// Toggle find settlement panel
    func toggleFindSettlement() {
        gameState?.toggleFindSettlement()
    }
    
    /// Prompt to save game
    func promptSaveGame() {
        if let state = gameState, state.canSaveGame {
            state.statusMessage = "Spiel speichern... (Noch nicht implementiert)"
        } else {
            gameState?.errorMessage = "Spiel kann derzeit nicht gespeichert werden."
        }
    }
    
    /// Toggle shortcuts help display
    func toggleShortcutsHelp() {
        gameState?.showShortcutsHelp.toggle()
    }
    
    /// Center map on selected unit
    func centerMapOnSelectedUnit() {
        if let unitTileId = gameState?.selectedUnitTileId {
            gameState?.requestMapScroll(to: unitTileId)
        }
    }
}
