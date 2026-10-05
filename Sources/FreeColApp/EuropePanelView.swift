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
                purchaseSection(local)
                marketSection(local)
                marketHistorySection
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
                        ForEach(Array(europe.recruitable.enumerated()), id: \.offset) { index, recruit in
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
                                Text("\(europe.recruitPrice) G")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Button(recruit.number > 1 ? "Recruit (x\(recruit.number))" : "Recruit") {
                                    state.recruitUnitInEurope(slot: index + 1)
                                }
                                .buttonStyle(.bordered)
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

    // MARK: - Market history

    private var marketHistorySection: some View {
        GroupBox("Market History") {
            let series = state.marketPriceHistory[selectedGoodsType] ?? []
            if selectedGoodsType.isEmpty || series.isEmpty {
                Text("Wähle eine Ware und handle, um den Preisverlauf zu sehen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goodsLabel(selectedGoodsType))
                            .font(.caption.bold())
                        Spacer()
                        Text("Last: \(series.last ?? 0) G · Min \(series.min() ?? 0) · Max \(series.max() ?? 0)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    PriceSparkline(values: series)
                        .frame(height: 48)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Purchase

    private func purchaseSection(_ local: Player) -> some View {
        let purchasable = state.purchasableEuropeUnits
        return GroupBox("Purchase Units") {
            if purchasable.isEmpty {
                Text("Keine kaufbaren Einheiten verfügbar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(purchasable, id: \.unitType) { unit in
                        HStack {
                            Text(unit.label)
                                .font(.caption)
                            Spacer()
                            Text("\(unit.price) G")
                                .font(.caption)
                                .foregroundColor(local.gold >= unit.price ? .yellow : .red)
                            Button("Buy") {
                                state.trainUnitInEurope(unitType: unit.unitType)
                            }
                            .buttonStyle(.bordered)
                            .disabled(local.gold < unit.price)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
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
                        Text("Goods").frame(width: 100, alignment: .leading)
                        Text("Buy").frame(width: 46, alignment: .trailing)
                        Text("Sell").frame(width: 46, alignment: .trailing)
                        Text("Stock").frame(width: 56, alignment: .trailing)
                        Spacer()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(marketData) { entry in
                                let prices = state.marketPrices(for: entry.goodsType)
                                HStack(spacing: 0) {
                                    Text(goodsLabel(entry.goodsType))
                                        .frame(width: 100, alignment: .leading)
                                        .font(.caption)
                                    Text("\(prices.costToBuy)")
                                        .frame(width: 46, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("\(prices.paidForSale)")
                                        .frame(width: 46, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text("\(entry.amount)")
                                        .frame(width: 56, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if entry.arrears > 0 {
                                        Button("Pay \(entry.arrears)") {
                                            state.payArrears(goodsTypeId: entry.goodsType ?? "")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(!state.canPayArrears(for: entry.goodsType))
                                    }
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
                        let limits = state.europeMarketTradeLimits(
                            goodsTypeId: selectedGoodsType,
                            carrierId: selectedCarrierId
                        )
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
                            .disabled(!canTrade || requestedTradeAmount > limits.sell)
                            Button("Buy") {
                                trade(selectedGoodsType, amount: Int(tradeAmount) ?? 0, sell: false)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canTrade || requestedTradeAmount > limits.buy)
                        }
                        Text("Buy limit: \(limits.buy) · cargo to sell: \(limits.sell)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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

    private var requestedTradeAmount: Int {
        Int(tradeAmount) ?? 0
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

/// A minimal step sparkline for recorded market prices.
private struct PriceSparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.15))
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.yellow, lineWidth: 1.5)
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(1, maxValue - minValue)
        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat(value - minValue) / CGFloat(span))
            return CGPoint(x: x, y: y)
        }
    }
}
