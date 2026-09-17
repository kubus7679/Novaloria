import SwiftUI
import FreeColProtocol

/// Read-only report surface for server `highScores` and `nationSummary` messages.
struct ReportsView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reports")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }

            if state.nationSummaryReport == nil && state.highScoresReport == nil {
                Text("Keine Berichte verfügbar.")
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
        GroupBox("Nation Summary") {
            VStack(alignment: .leading, spacing: 4) {
                let player = summary.attributes["player"] ?? "?"
                Text("Player: \(player)")
                    .font(.caption.bold())
                reportRow("Settlements", summary.attributes["numberOfSettlements"])
                reportRow("Units", summary.attributes["numberOfUnits"])
                reportRow("Military", summary.attributes["militaryStrength"])
                reportRow("Naval", summary.attributes["navalStrength"])
                reportRow("Gold", summary.attributes["gold"])
                reportRow("SoL", summary.attributes["SoL"])
                reportRow("Tax", summary.attributes["tax"])
                reportRow("Stance", summary.attributes["stance"])
            }
            .padding(.vertical, 4)
        }
    }

    private func highScoresSection(_ report: ParsedMessage) -> some View {
        GroupBox("High Scores") {
            VStack(alignment: .leading, spacing: 4) {
                let entries = report.children.filter { $0.tag == "highScore" }
                if entries.isEmpty {
                    Text("Keine Einträge.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 0) {
                        Text("Player").frame(width: 120, alignment: .leading)
                        Text("Nation").frame(width: 90, alignment: .leading)
                        Text("Score").frame(width: 55, alignment: .trailing)
                        Text("Units").frame(width: 45, alignment: .trailing)
                        Text("Colonies").frame(width: 60, alignment: .trailing)
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
