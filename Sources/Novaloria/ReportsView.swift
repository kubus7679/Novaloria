import SwiftUI
import FreeColProtocol

/// Read-only report surface for server `highScores` and `nationSummary` messages.
struct ReportsView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Berichte", table: "ReportsView"))
                    .font(.title2.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "ReportsView")) { dismiss() }
            }

            if state.nationSummaryReport == nil && state.highScoresReport == nil {
                Text(L10n.text("Keine Berichte verfügbar.", table: "ReportsView"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let summary = state.nationSummaryReport {
                nationSummarySection(summary)
            }

            if let scores = state.highScoresReport {
                highScoresSection(scores)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func nationSummarySection(_ summary: ParsedMessage) -> some View {
        GroupBox(L10n.text("Nationsübersicht", table: "ReportsView")) {
            VStack(alignment: .leading, spacing: 4) {
                let player = summary.attributes["player"] ?? "?"
                Text(L10n.text("Spieler: \(player)", table: "ReportsView"))
                    .font(.caption.bold())
                reportRow("Siedlungen", summary.attributes["numberOfSettlements"])
                reportRow(L10n.text("Einheiten", table: "ReportsView"), summary.attributes["numberOfUnits"])
                reportRow(L10n.text("Militär", table: "ReportsView"), summary.attributes["militaryStrength"])
                reportRow(L10n.text("Flotte", table: "ReportsView"), summary.attributes["navalStrength"])
                reportRow(L10n.text("Gold", table: "ReportsView"), summary.attributes["gold"])
                reportRow(L10n.text("Freiheitsbewusstsein", table: "ReportsView"), summary.attributes["SoL"])
                reportRow(L10n.text("Steuer", table: "ReportsView"), summary.attributes["tax"])
                reportRow(L10n.text("Haltung", table: "ReportsView"), summary.attributes["stance"])
            }
            .padding(.vertical, 4)
        }
    }

    private func highScoresSection(_ report: ParsedMessage) -> some View {
        GroupBox(L10n.text("Bestenliste", table: "ReportsView")) {
            VStack(alignment: .leading, spacing: 4) {
                let entries = report.children.filter { $0.tag == "highScore" }
                if entries.isEmpty {
                    Text(L10n.text("Keine Einträge.", table: "ReportsView"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 0) {
                        Text(L10n.text("Spieler", table: "ReportsView")).frame(width: 120, alignment: .leading)
                        Text(L10n.text("Nation", table: "ReportsView")).frame(width: 90, alignment: .leading)
                        Text(L10n.text("Punkte", table: "ReportsView")).frame(width: 55, alignment: .trailing)
                        Text(L10n.text("Einheiten", table: "ReportsView")).frame(width: 45, alignment: .trailing)
                        Text(L10n.text("Kolonien", table: "ReportsView")).frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 0) {
                            Text(entry.attributes["playerName"] ?? "?")
                                .frame(width: 120, alignment: .leading)
                            Text(entry.attributes["nationName"] ?? entry.attributes["nationId"] ?? "?")
                                .frame(width: 90, alignment: .leading)
                            Text(entry.attributes["score"] ?? "?")
                                .frame(width: 55, alignment: .trailing)
                            Text(entry.attributes["units"] ?? "?")
                                .frame(width: 45, alignment: .trailing)
                            Text(entry.attributes["colonies"] ?? "?")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func reportRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value ?? "-")
                .font(.caption)
        }
    }
}
