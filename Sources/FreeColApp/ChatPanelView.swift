import SwiftUI

/// In-game chat transcript with outbound message entry.
struct ChatPanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Chat")
                    .font(.title3.bold())
                Spacer()
                Button("Schließen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if state.incomingChatLog.isEmpty {
                            Text("Noch keine Nachrichten.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ForEach(Array(state.incomingChatLog.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(6)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .onChange(of: state.incomingChatLog.count) { _, newValue in
                    if newValue > 0 {
                        proxy.scrollTo(newValue - 1, anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Nachricht", text: $message)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("Senden", action: send)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 340)
    }

    private func send() {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state.sendChatMessage(message: text, privateRecipientId: "")
        message = ""
    }
}
