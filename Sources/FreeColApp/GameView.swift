import SwiftUI
import FreeColClient
import FreeColGame

struct GameView: View {
    @Environment(GameState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HSplitView {
                MapView()
                    .frame(minWidth: 400)
                infoPanel
                    .frame(width: 250)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Disconnect") { state.disconnect() }
            }
        }
    }

    private var topBar: some View {
        HStack {
            if let game = state.game {
                Text("Turn \(game.turn.number)")
                    .font(.headline)
                if let cp = game.currentPlayerId, let player = game.players[cp] {
                    Text(player.name ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if !state.statusMessage.isEmpty {
                Text(state.statusMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let game = state.game {
                    GroupBox("Players") {
                        let sorted = game.players.values
                            .filter { $0.playerType == .european }
                        ForEach(Array(sorted), id: \.id) { player in
                            HStack {
                                Circle().fill(colorFor(player: player))
                                    .frame(width: 8, height: 8)
                                Text(player.name ?? player.nationId ?? "?")
                                    .lineLimit(1)
                                Spacer()
                                Text("\(player.gold) G")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }

                    GroupBox("Units") {
                        ForEach(game.units.values.filter { $0.owner == game.currentPlayerId }, id: \.id) { unit in
                            HStack {
                                Text(unit.unitType ?? "Unit")
                                    .font(.caption)
                                Spacer()
                                Text(unit.state.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    GroupBox("Colonies") {
                        let colonyList = Array(game.colonies.values)
                        ForEach(colonyList, id: \.id) { colony in
                            HStack {
                                Text(colony.name ?? "?")
                                    .font(.caption)
                                Spacer()
                                Text("\(colony.sonsOfLiberty)% SoL")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func colorFor(player: Player) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(player.id.hashValue) % colors.count
        return colors[idx]
    }
}
