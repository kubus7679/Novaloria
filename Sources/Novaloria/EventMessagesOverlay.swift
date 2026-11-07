import SwiftUI
import FreeColGame
import NovaloriaClient

struct EventMessagesOverlay: View {
    @Environment(GameState.self) private var state
    
    @State private var readMessageIds: Set<String> = []
    
    var unreadMessages: [(id: String, message: ModelMessage)] {
        state.localPlayerModelMessages.enumerated().compactMap { index, message in
            let id = "\(index)|\(message.notificationID)"
            return readMessageIds.contains(id) ? nil : (id, message)
        }
    }
    
    var body: some View {
        if !unreadMessages.isEmpty {
            VStack(spacing: 8) {
                ForEach(unreadMessages, id: \.id) { item in
                    messageView(for: item.message, notificationID: item.id)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private func messageView(for message: ModelMessage, notificationID: String) -> some View {
        HStack(spacing: 8) {
            if let image = eventMessageImage(for: message) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.modelMessageText(message))
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 4)
        .frame(maxWidth: 400)
        .onTapGesture {
            readMessageIds.insert(notificationID)
        }
    }
    
    private func eventMessageImage(for message: ModelMessage) -> NSImage? {
        let imageName: String?
        if let type = message.messageType?.lowercased() {
            if type.contains("gold") { imageName = "gold" }
            else if type.contains("combat") || type.contains("attack") { imageName = "sword" }
            else if type.contains("trade") { imageName = "trade" }
            else if type.contains("colony") { imageName = "colony_small" }
            else if type.contains("unit") { imageName = "freeColonist" }
            else if type.contains("resource") { imageName = "resource_silver" }
            else { imageName = nil }
        } else {
            imageName = nil
        }
        guard let imageName else { return nil }
        return TileImageCache.shared.loadImage(named: imageName, folder: "terrain")
            ?? TileImageCache.shared.loadImage(named: imageName, folder: "units")
            ?? TileImageCache.shared.loadImage(named: imageName, folder: "goods")
    }
    
    func resetReadMessages() {
        readMessageIds.removeAll()
    }
}
