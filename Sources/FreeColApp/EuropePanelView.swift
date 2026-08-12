import SwiftUI
import FreeColGame

/// Europe dock panel, modelled on the Java client's EuropePanel:
/// recruit slots, market price list with click-to-trade, purchases summary and ships in port.
struct EuropePanelView: View {
    @Environment(GameState.self) private var state

    @State private var selectedCarrierId: String = ""
    @State private var selectedGoodsType: String = ""
    @State private var tradeAmount: String = "10"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Europe")
                    .font(.title2.bold())
                Spacer()
                if let local = state.localPlayer {
                    Text("Gold: \(local.gold)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                Button("Close") { state.closeEuropePanel() }
            }

            if let local = state.localPlayer {
                recruitSection(local)
                marketSection(local)
                purchasesSummary(local)
                shipsSection(local)
            } else {
                Text("Keine Europa-Daten verfügbar.")
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Recruit

    private func recruitSection(_ local: Player) -> some View {
        GroupBox("Recruit") {
            VStack(alignment: .leading, spacing: 6) {
                if let europe = local.europe {
                    if europe.recruitable.isEmpty {
                        Text("Keine Rekruten verfügbar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(europe.recruitable) { recruit in
                            HStack {
                                if let nsImg = TileImageCache.shared.unitImage(forUnitType: recruit.unitType) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 26, height: 26)
                                } else {
                                    Image(systemName: "person.fill")
                                        .frame(width: 26, height: 26)
                                }
                                Text(unitLabel(recruit.unitType))
                                    .font(.caption)
                                Spacer()
                                Text("\(europe.price(for: recruit.unitType)) G")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Button(recruit.number > 1 ? "Train (x\(recruit.number))" : "Train") {
                                    state.trainUnitInEurope(unitType: recruit.unitType ?? "")
                                }
                                .buttonStyle(.bordered)
                                .disabled(recruit.unitType == nil)
                            }
                        }
                    }
                    Text("Recruitment price rises: \(europe.recruitPrice) G base")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Market

    private func marketSection(_ local: Player) -> some View {
        GroupBox("Market") {
            VStack(alignment: .leading, spacing: 6) {
                let marketData = state.localPlayerMarketData
                if marketData.isEmpty {
                    Text("Keine Marktdaten verfügbar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 0) {
                        Text("Goods").frame(width: 110, alignment: .leading)
                        Text("Price").frame(width: 60, alignment: .trailing)
                        Text("In stock").frame(width: 70, alignment: .trailing)
                        Spacer()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(marketData) { entry in
                                HStack(spacing: 0) {
                                    Text(goodsLabel(entry.goodsType))
                                        .frame(width: 110, alignment: .leading)
                                        .font(.caption)
                                    Text("\(entry.initialPrice) G")
                                        .frame(width: 60, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text("\(entry.amount)")
                                        .frame(width: 70, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("Sell") {
                                        selectedGoodsType = entry.goodsType ?? ""
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .background(selectedGoodsType == entry.goodsType
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedGoodsType = entry.goodsType ?? ""
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)

                    if !selectedGoodsType.isEmpty {
                        HStack {
                            Text("Goods: \(goodsLabel(selectedGoodsType))")
                                .font(.caption)
                            Spacer()
                            TextField("Amount", text: $tradeAmount)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Button("Sell") {
                                trade(selectedGoodsType, amount: Int(tradeAmount) ?? 0, sell: true)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canTrade)
                            Button("Buy") {
                                trade(selectedGoodsType, amount: Int(tradeAmount) ?? 0, sell: false)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canTrade)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var canTrade: Bool {
        state.isLocalPlayersTurn && !selectedCarrierId.isEmpty
            && (Int(tradeAmount) ?? 0) > 0 && !selectedGoodsType.isEmpty
    }

    private func trade(_ goodsType: String, amount: Int, sell: Bool) {
        if sell {
            state.sellGoodsInEurope(goodsTypeId: goodsType, amount: amount, carrierId: selectedCarrierId)
        } else {
            state.buyGoodsInEurope(goodsTypeId: goodsType, amount: amount, carrierId: selectedCarrierId)
        }
    }

    // MARK: - Purchases

    private func purchasesSummary(_ local: Player) -> some View {
        GroupBox("Purchases") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recruits: \(state.purchasesRecruits)")
                    Text("\(state.purchasesTrained) units trained")
                }
                .font(.caption)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total: \(state.purchasesTotal) G")
                    Text("Net profit: \(state.purchasesNetProfit) G")
                        .foregroundColor(state.purchasesNetProfit >= 0 ? .green : .red)
                }
                .font(.caption)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Ships in port

    private func shipsSection(_ local: Player) -> some View {
        GroupBox("Ships in Port") {
            VStack(alignment: .leading, spacing: 4) {
                if state.europeCarrierUnits.isEmpty {
                    Text("Keine Schiffe im Hafen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(state.europeCarrierUnits, id: \.id) { carrier in
                        Button {
                            selectedCarrierId = carrier.id
                        } label: {
                            HStack {
                                if let nsImg = TileImageCache.shared.unitImage(forUnitType: carrier.unitType) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 22, height: 22)
                                } else {
                                    Image(systemName: "sailboat.fill")
                                        .frame(width: 22, height: 22)
                                }
                                Text(unitLabel(carrier.unitType))
                                    .font(.caption)
                                Spacer()
                                Text(cargoLabel(carrier))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if selectedCarrierId == carrier.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if selectedCarrierId.isEmpty {
                        Text("Schiff für Handel auswählen.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func cargoLabel(_ carrier: FreeColGame.Unit) -> String {
        guard let game = state.game else { return "" }
        let aboard = game.units.values.filter { $0.location == carrier.id }.count
        return aboard > 0 ? "\(aboard) aboard" : "empty"
    }

    private func unitLabel(_ unitType: String?) -> String {
        guard let unitType else { return "?" }
        if unitType.hasPrefix("model.unit.") {
            return String(unitType.dropFirst("model.unit.".count))
        }
        return unitType
    }

    private func goodsLabel(_ goodsType: String?) -> String {
        guard let goodsType else { return "?" }
        if goodsType.hasPrefix("model.goods.") {
            return String(goodsType.dropFirst("model.goods.".count))
        }
        return goodsType
    }
}