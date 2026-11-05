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
        guard gameState.pendingServerDecision == nil else { return false }
        guard let manager = gameState.keyboardShortcutsManager else { return false }

        guard let key = keyString(for: event) else { return false }

        let handled = handleSpecialKeys(key, modifierFlags: event.modifierFlags)
        if handled {
            return true
        }

        return manager.handleKeyPress(key, modifierFlags: event.modifierFlags)
    }

    private func keyString(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36, 76: return "enter"
        case 53: return "escape"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return event.charactersIgnoringModifiers?.lowercased()
        }
    }
    
    private func handleSpecialKeys(_ key: String, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        switch key.lowercased() {
        case "escape":
            // Close panels
            if gameState.showShortcutsHelp {
                gameState.showShortcutsHelp = false
                return true
            }
            if gameState.isChoosingMoveDestination {
                gameState.cancelChoosingMoveDestination()
                return true
            }
            
        case "enter":
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

    static func dismantleNSView(_ nsView: KeyboardEventNSView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

/// Installs a window-scoped event monitor so shortcuts work regardless of first responder.
final class KeyboardEventNSView: NSView {
    var onKeyEvent: ((NSEvent) -> Bool)?

    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopMonitoring()
        } else if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let window = self.window,
                      event.window === window,
                      window.isKeyWindow,
                      !(window.firstResponder is NSTextView),
                      !(window.firstResponder is NSTextField) else {
                    return event
                }
                return self.onKeyEvent?(event) == true ? nil : event
            }
        }
    }

    func stopMonitoring() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }
}
