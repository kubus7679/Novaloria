//
//  KeyboardShortcutHandlerView.swift
//  FreeColClient
//
//  Handles keyboard shortcuts for the game view.
//

import SwiftUI
import AppKit

/// View that handles keyboard shortcuts for the entire game
struct KeyboardShortcutHandlerView<Content: View>: View {
    @Environment(GameState.self) private var gameState
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                KeyboardEventHandlerView { event in
                    handleKeyEvent(event)
                }
            )
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let manager = gameState.keyboardShortcutsManager else { return false }
        
        // Only handle key down events
        guard event.type == .keyDown else { return false }
        
        // Get the key string
        guard let characters = event.characters, !characters.isEmpty else { return false }
        let key = characters
        
        // Handle special keys
        let handled = handleSpecialKeys(key, modifierFlags: event.modifierFlags)
        if handled {
            return true
        }
        
        // Let the shortcut manager handle it
        // For single character keys
        if key.count == 1 {
            let handled = manager.handleKeyPress(key, modifierFlags: event.modifierFlags)
            if handled {
                return true
            }
        }
        
        return false
    }
    
    private func handleSpecialKeys(_ key: String, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        switch key.lowercased() {
        case "\u{1b}": // Escape
            // Close panels
            if gameState.showShortcutsHelp {
                gameState.showShortcutsHelp = false
                return true
            }
            if gameState.isChoosingMoveDestination {
                gameState.cancelChoosingMoveDestination()
                return true
            }
            
        case "\r", "\n": // Enter/Return
            if modifierFlags.contains(.control) {
                // Ctrl+Enter = End turn
                if gameState.canEndTurn {
                    gameState.requestEndTurn()
                    return true
                }
            }
            
        default:
            break
        }
        
        return false
    }
}

/// View that captures keyboard events
struct KeyboardEventHandlerView: NSViewRepresentable {
    var onKeyEvent: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> KeyboardEventNSView {
        let view = KeyboardEventNSView()
        view.onKeyEvent = onKeyEvent
        return view
    }
    
    func updateNSView(_ nsView: KeyboardEventNSView, context: Context) {
        nsView.onKeyEvent = onKeyEvent
    }
}

/// NSView that captures keyboard events
final class KeyboardEventNSView: NSView {
    var onKeyEvent: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let onKeyEvent = onKeyEvent, onKeyEvent(event) {
            // Event was handled
            return
        }
        // Pass to super
        super.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
    }
}


