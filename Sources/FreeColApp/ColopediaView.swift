import SwiftUI
import FreeColGame

/// Lightweight in-game help browser for unit and goods types from the specification.
struct ColopediaView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var spec: Specification? { state.game?.specification }

    private var unitTypes: [UnitTypeInfo] {
        let all = spec?.unitTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var goodsTypes: [GoodsTypeInfo] {
        let all = spec?.goodsTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Colopedia")
                    .font(.title3.bold())
                Spacer()
                Button("Close") { dismiss() }
            }

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)

            if spec == nil || (unitTypes.isEmpty && goodsTypes.isEmpty) {
                Spacer()
                Text("No specification data available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !unitTypes.isEmpty {
                            GroupBox("Unit Types") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(unitTypes, id: \.id) { info in
                                        HStack {
                                            Text(short(info.id, prefix: "model.unit."))
                                                .frame(width: 200, alignment: .leading)
                                            Text("Sight: \(info.lineOfSight)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Atk \(info.offence) / Def \(info.defence) / Mov \(info.movement)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !goodsTypes.isEmpty {
                            GroupBox("Goods Types") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(goodsTypes, id: \.id) { info in
                                        Text(short(info.id, prefix: "model.goods."))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }

    private func short(_ value: String, prefix: String) -> String {
        value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }
}
