import SwiftUI
import FreeColGame

/// Game status / statistics overview (Java `StatusPanel` / `StatisticsPanel`).
struct StatusPanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spielstatus")
                    .font(.title2.bold())
                Spacer()
                Button("Schließen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 12) {
            if let game = state.game {
                GroupBox("Spiel") {
                    VStack(alignment: .leading, spacing: 4) {
                        row("Spielkennung", game.id)
                        row("Runde", "\(game.turn.number)")
                        row("Aktueller Spieler", game.players[game.currentPlayerId ?? ""]?.name ?? "—")
                        row("Spieler", "\(game.players.count)")
                        row("Kolonien", "\(game.colonies.count)")
                        row("Einheiten", "\(game.units.count)")
                        if !game.tiles.isEmpty {
                            let explored = game.exploredTileIds().count
                            let total = game.tiles.count
                            let percent = total > 0 ? Int(Double(explored) / Double(total) * 100) : 0
                             row("Erkundet", "\(explored) / \(total) (\(percent)%)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Spieler") {
                    playerTable(game: game)
                        .padding(.vertical, 4)
                }

                GroupBox("Eigener Spieler") {
                    if let local = state.localPlayer {
                        VStack(alignment: .leading, spacing: 4) {
                            row("Name", local.name ?? local.id)
                            row("Gold", "\(local.gold)")
                            row("Steuern", "\(local.tax)%")
                            row("Einwanderung", "\(local.immigration)")
                            row("Freiheit", "\(local.liberty)")
                            row("Punkte", "\(local.score)")
                            row("Gründerväter", "\(local.foundingFathers.count)")
                            row("Spielmeldungen", "\(local.modelMessages.count)")
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Kein eigener Spieler.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Kein Spiel geladen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 640, idealWidth: 720,
               minHeight: 400, idealHeight: 640, maxHeight: 760)
    }

    @ViewBuilder
    private func playerTable(game: Game) -> some View {
        let players = state.lobbyPlayers
        if players.isEmpty {
            Text("Keine Spieler.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Spieler").frame(width: 110, alignment: .leading)
                    Text("Nation").frame(width: 90, alignment: .leading)
                    Text("Typ").frame(width: 150, alignment: .leading)
                    Text("Gold").frame(width: 60, alignment: .trailing)
                    Text("Punkte").frame(width: 50, alignment: .trailing)
                    Text("Einheiten").frame(width: 45, alignment: .trailing)
                    Text("Kolonien").frame(width: 60, alignment: .trailing)
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)

                ForEach(players) { player in
                    let units = game.units.values.filter { $0.owner == player.id }.count
                    let colonies = game.colonies.values.filter { $0.owner == player.id }.count
                    HStack(spacing: 0) {
                        Text(player.name ?? player.id)
                            .frame(width: 110, alignment: .leading)
                            .foregroundColor(player.id == state.localPlayerId ? .yellow : .primary)
                        Text(short(player.nationId, prefix: "model.nation."))
                            .frame(width: 90, alignment: .leading)
                        Text(playerTypeLabel(player))
                            .frame(width: 150, alignment: .leading)
                        Text("\(player.gold)")
                            .frame(width: 60, alignment: .trailing)
                        Text("\(player.score)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(units)")
                            .frame(width: 45, alignment: .trailing)
                        Text("\(colonies)")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func playerTypeLabel(_ player: Player) -> String {
        switch player.playerType {
        case .indian: return "Ureinwohner"
        case .ref: return "Königliche Expeditionsstreitkräfte"
        case .undead: return "Untot"
        case .european: return player.ai ? "KI" : "Mensch"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private func short(_ value: String?, prefix: String) -> String {
        guard let value else { return "—" }
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }
}
