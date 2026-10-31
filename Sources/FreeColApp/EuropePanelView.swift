import SwiftUI
import FreeColGame

/// Europe dock panel, modelled on the Java client's EuropePanel:
/// recruit slots, market price list with click-to-trade, purchases summary and ships in port.
struct EuropePanelView: View {
    @Environment(GameState.self) private var state

    @State private var selectedCarrierId: String = ""
    @State private var selectedGoodsType: String = ""
    @State private var tradeAmount: String = "10"
    @State private var section: EuropeSection = .harbor

    enum EuropeSection: String, CaseIterable {
        case harbor = "Hafen und Fracht"
        case market = "Markt"
        case recruitment = "Rekrutierung"
    }

    init(section: EuropeSection = .harbor) {
        _section = State(initialValue: section)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Europa")
                    .font(.title2.bold())
                Spacer()
                if let local = state.localPlayer {
                    Text("Gold: \(local.gold)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                Button("Schließen") { state.closeEuropePanel() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
            }
            .padding(16)

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Picker("Bereich", selection: $section) {
                    ForEach(EuropeSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("europe-section")
                Picker("Handelsschiff", selection: $selectedCarrierId) {
                    Text("Kein Schiff ausgewählt").tag("")
                    ForEach(state.europeCarrierUnits) { carrier in
                        Text("\(unitLabel(carrier.unitType)) · \(carrier.name ?? cargoLabel(carrier))").tag(carrier.id)
                    }
                }
            }
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let local = state.localPlayer {
                        switch section {
                        case .harbor:
                            shipsSection(local)
                            dockSection
                            purchasesSummary(local)
                        case .market:
                            marketSection(local)
                            marketHistorySection
                        case .recruitment:
                            recruitSection(local)
                            purchaseSection(local)
                        }
                    } else {
                        Text("Keine Europa-Daten verfügbar.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(
            minWidth: 600, maxWidth: 1000,
            minHeight: 400, idealHeight: 480, maxHeight: 760
        )
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { syncCarrierSelection() }
        .onChange(of: state.europeCarrierUnits.map(\.id)) { _, _ in syncCarrierSelection() }
    }

    // MARK: - Recruit

    private func recruitSection(_ local: Player) -> some View {
        GroupBox("Rekrutierung") {
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
                                Text(
                                    state.europeRecruitmentCost.map { $0 == 0 ? "Kostenlos" : "\($0) G" }
                                        ?? "Preis unbekannt"
                                )
                                .font(.caption)
                                .foregroundColor(.yellow)
                                Button(recruit.number > 1 ? "Anwerben (×\(recruit.number))" : "Anwerben") {
                                    state.recruitUnitInEurope(slot: index + 1)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canRecruitInEurope || !state.canChooseEuropeRecruit || index >= 3)
                            }
                        }
                    }
                    if state.europeRecruitmentCost == 0, !state.canChooseEuropeRecruit {
                        Button("Kostenlosen Auswanderer aufnehmen (Zufall)") {
                            state.recruitUnitInEurope(slot: 0)
                        }
                        .disabled(!state.canRecruitInEurope)
                    }
                    Text(
                        state.europeRecruitmentCost == nil
                            ? "Einwanderungsschwelle fehlt in den Serverdaten."
                            : "Anwerbung abhängig von Einwanderungspunkten; Grundpreis: \(europe.recruitPrice) G"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Market history

    private var marketHistorySection: some View {
        GroupBox("Preisverlauf") {
            let buySeries = state.marketBuyPriceHistory[selectedGoodsType] ?? []
            let saleSeries = state.marketPriceHistory[selectedGoodsType] ?? []
            if selectedGoodsType.isEmpty || (buySeries.isEmpty && saleSeries.isEmpty) {
                Text("Wähle eine Ware und handle, um den Preisverlauf zu sehen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goodsLabel(selectedGoodsType))
                            .font(.caption.bold())
                        Spacer()
                    }
                    HStack {
                        Text(priceHistorySummary("Kauf", values: buySeries))
                            .foregroundColor(.orange)
                        Spacer()
                        Text(priceHistorySummary("Verkauf", values: saleSeries))
                            .foregroundColor(.yellow)
                    }
                    .font(.caption2)
                    PriceSparkline(
                        buyValues: buySeries.map { $0.price },
                        saleValues: saleSeries.map { $0.price },
                        buyTurns: buySeries.map { $0.turn },
                        saleTurns: saleSeries.map { $0.turn }
                    )
                    .frame(height: 48)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func priceHistorySummary(_ label: String, values: [(turn: Int, price: Int)]) -> String {
        guard let latest = values.last?.price else { return "\(label): —" }
        let minPrice = values.map { $0.price }.min() ?? values.last!.price
        let maxPrice = values.map { $0.price }.max() ?? values.last!.price
        let firstTurn = values.first?.turn ?? 0
        let lastTurn = values.last?.turn ?? 0
        return "\(label): \(latest) G (\(minPrice)–\(maxPrice)), Runden \(firstTurn)–\(lastTurn)"
    }

    // MARK: - Purchase

    private func purchaseSection(_ local: Player) -> some View {
        let purchasable = state.purchasableEuropeUnits
        return GroupBox("Kauf und Ausbildung") {
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
                            Button("Kaufen") {
                                state.trainUnitInEurope(unitType: unit.unitType)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.isLocalPlayersTurn || local.gold < unit.price)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Market

    private func marketSection(_ local: Player) -> some View {
        GroupBox("Markt") {
            VStack(alignment: .leading, spacing: 6) {
                let marketData = state.localPlayerMarketData
                if marketData.isEmpty {
                    Text("Keine Marktdaten verfügbar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 6) {
                        Text("Ware").frame(width: 120, alignment: .leading)
                        Text("Kauf").frame(width: 46, alignment: .trailing)
                        Text("Verkauf").frame(width: 56, alignment: .trailing)
                        Text("Vorrat").frame(width: 56, alignment: .trailing)
                        Text("Trend").frame(width: 40, alignment: .center)
                        Spacer()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(marketData) { entry in
                                let prices = state.marketPrices(for: entry.goodsType)
                                HStack(spacing: 6) {
                                    Text(goodsLabel(entry.goodsType))
                                        .frame(width: 120, alignment: .leading)
                                        .font(.caption)
                                    Text("\(prices.costToBuy)")
                                        .frame(width: 46, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("\(prices.paidForSale)")
                                        .frame(width: 56, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text("\(entry.amount)")
                                        .frame(width: 56, alignment: .trailing)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(state.marketPriceTrend(for: entry.goodsType)?.rawValue ?? "→")
                                        .frame(width: 40, alignment: .center)
                                        .font(.caption)
                                        .foregroundColor(trendColor(for: entry.goodsType))
                                    Spacer()
                                    if entry.arrears > 0 {
                                        Button("\(entry.arrears) G zahlen") {
                                            state.payArrears(goodsTypeId: entry.goodsType ?? "")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(!state.canPayArrears(for: entry.goodsType))
                                    }
                                    Button("Auswählen") {
                                        selectedGoodsType = entry.goodsType ?? ""
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .background(
                                    selectedGoodsType == entry.goodsType
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedGoodsType = entry.goodsType ?? ""
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)

                    if !selectedGoodsType.isEmpty {
                        let arrears = state.arrears(for: selectedGoodsType)
                        let limits = state.europeMarketTradeLimits(
                            goodsTypeId: selectedGoodsType,
                            carrierId: selectedCarrierId
                        )
                        HStack {
                            Text("Ware: \(goodsLabel(selectedGoodsType))")
                                .font(.caption)
                            Spacer()
                            TextField("Menge", text: $tradeAmount)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Button("Verkaufen") {
                                trade(selectedGoodsType, amount: Int(tradeAmount) ?? 0, sell: true)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canTrade || arrears > 0 || requestedTradeAmount > limits.sell)
                            Button("Kaufen") {
                                trade(selectedGoodsType, amount: Int(tradeAmount) ?? 0, sell: false)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canTrade || arrears > 0 || requestedTradeAmount > limits.buy)
                        }
                        HStack {
                            Button("Max. Kauf") {
                                tradeAmount = String(limits.buy)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(
                                !state.isLocalPlayersTurn
                                    || selectedCarrierId.isEmpty
                                    || limits.buy == 0)

                            Button("Max. Verkauf") {
                                tradeAmount = String(limits.sell)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(
                                !state.isLocalPlayersTurn
                                    || selectedCarrierId.isEmpty
                                    || limits.sell == 0)

                            Spacer()
                            Text(
                                arrears > 0
                                    ? "Boykott: zuerst \(arrears) G Rückstände zahlen"
                                    : "Kauflimit: \(limits.buy) · Verkaufslimit: \(limits.sell)"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        if arrears == 0,
                            let quote = state.europeMarketTradeQuote(
                                goodsTypeId: selectedGoodsType,
                                amount: requestedTradeAmount
                            )
                        {
                            Text("Schätzung: Kauf \(quote.buyTotal) G · Verkauf nach Steuern \(quote.sellAfterTax) G")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
        GroupBox("Handelsbilanz") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rekrutiert: \(state.purchasesRecruits)")
                    Text("Ausgebildet: \(state.purchasesTrained)")
                }
                .font(.caption)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ausgaben: \(state.purchasesTotal) G")
                    Text("Nettogewinn: \(state.purchasesNetProfit) G")
                        .foregroundColor(state.purchasesNetProfit >= 0 ? .green : .red)
                }
                .font(.caption)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Ships in port

    private func shipsSection(_ local: Player) -> some View {
        GroupBox("Schiffe im Hafen") {
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
                    if let carrier = state.europeCarrierUnits.first(where: { $0.id == selectedCarrierId }) {
                        Divider()
                        Text("Fracht")
                            .font(.headline)
                        ForEach(carrier.goods.keys.sorted(), id: \.self) { type in
                            Text("\(goodsLabel(type)): \(carrier.goods[type] ?? 0)")
                        }
                        let passengers = state.game?.units.values.filter { $0.location == carrier.id } ?? []
                        ForEach(passengers.sorted { $0.id < $1.id }) { unit in
                            Text(unitLabel(unit.unitType))
                        }
                        if carrier.goods.isEmpty && passengers.isEmpty {
                            Text("Keine Fracht oder Passagiere.")
                                .foregroundStyle(.secondary)
                        }
                        Button("Mit diesem Schiff handeln") { section = .market }
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

    private var dockSection: some View {
        GroupBox("Docks") {
            VStack(alignment: .leading, spacing: 8) {
                let dockUnits = state.europeUnits.filter { !state.isCarrierUnit($0) }
                if dockUnits.isEmpty {
                    Text("Keine Einheiten an den Docks.").foregroundStyle(.secondary)
                }
                ForEach(dockUnits) { unit in
                    Label(unitLabel(unit.unitType), systemImage: "person")
                }
                let traveling =
                    state.game?.units.values.filter {
                        $0.owner == state.localPlayerId
                            && ($0.state == .sailing || $0.state == .toEurope || $0.state == .toAmerica
                                || $0.location?.hasPrefix("highSeas:") == true)
                    } ?? []
                if !traveling.isEmpty {
                    Divider()
                    Text("Auf See").font(.headline)
                    ForEach(traveling.sorted { $0.id < $1.id }) { unit in
                        Text("\(unitLabel(unit.unitType)) · \(max(0, unit.workLeft)) Runden")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func syncCarrierSelection() {
        if !state.europeCarrierUnits.contains(where: { $0.id == selectedCarrierId }) {
            selectedCarrierId = state.europeCarrierUnits.first?.id ?? ""
        }
    }

    private func trendColor(for goodsType: String?) -> Color {
        guard let goodsType,
            let trend = state.marketPriceTrend(for: goodsType)
        else { return .secondary }
        switch trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .secondary
        }
    }

    private func cargoLabel(_ carrier: FreeColGame.Unit) -> String {
        guard let game = state.game else { return "" }
        let aboard = game.units.values.filter { $0.location == carrier.id }.count
        return "\(aboard) Passagiere · \(carrier.goods.values.reduce(0, +)) Waren"
    }

    private func unitLabel(_ unitType: String?) -> String {
        guard let unitType else { return "?" }
        return state.unitDisplayName(unitType)
    }

    private func goodsLabel(_ goodsType: String?) -> String {
        guard let goodsType else { return "?" }
        return state.goodsDisplayName(goodsType)
    }
}

/// A minimal step sparkline for recorded market prices with time axis.
private struct PriceSparkline: View {
    let buyValues: [Int]
    let saleValues: [Int]
    let buyTurns: [Int]
    let saleTurns: [Int]

    var body: some View {
        GeometryReader { geo in
            let allValues = buyValues + saleValues
            let minValue = allValues.min() ?? 0
            let maxValue = allValues.max() ?? 1
            let span = max(1, maxValue - minValue)
            
            let buyPoints = buyValues.enumerated().map { index, value in
                let x = geo.size.width * CGFloat(index) / CGFloat(buyValues.count - 1)
                let y = geo.size.height * (1 - CGFloat(buyValues[index] - minValue) / CGFloat(span))
                return CGPoint(x: x, y: y)
            }
            let salePoints = saleValues.enumerated().map { index, value in
                let x = geo.size.width * CGFloat(index) / CGFloat(saleValues.count - 1)
                let y = geo.size.height * (1 - CGFloat(saleValues[index] - minValue) / CGFloat(span))
                return CGPoint(x: x, y: y)
            }

            // Turn positions for axis labels
            let buyTurnPositions = buyTurns.enumerated().map { index, turn in
                geo.size.width * CGFloat(index) / CGFloat(buyTurns.count - 1)
            }
            let saleTurnPositions = saleTurns.enumerated().map { index, turn in
                geo.size.width * CGFloat(index) / CGFloat(saleTurns.count - 1)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.15))
                
                // Grid lines
                ForEach(0..<5) { i in
                    let y = geo.size.height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                }
                
                // Price labels on Y axis
                ForEach(0..<5) { i in
                    let price = minValue + (maxValue - minValue) * i / 4
                    let y = geo.size.height * (1 - CGFloat(i) / 4)
                    Text("\(price)")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                        .position(x: 15, y: y)
                }
                
                if buyPoints.count > 1 {
                    Path { path in
                        path.move(to: buyPoints[0])
                        for point in buyPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.orange, lineWidth: 1.5)
                }
                if salePoints.count > 1 {
                    Path { path in
                        path.move(to: salePoints[0])
                        for point in salePoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.yellow, lineWidth: 1.5)
                }
                
                // Turn labels on X axis
                if buyPoints.count > 1 && buyTurns.count > 1 {
                    ForEach(0..<buyTurns.count, id: \.self) { i in
                        if i % max(1, buyTurns.count / 4) == 0 {
                            let turn = buyTurns[i]
                            let x = buyPoints[i].x
                            Text("T\(turn)")
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                                .position(x: x, y: geo.size.height + 12)
                        }
                    }
                }
                if salePoints.count > 1 && saleTurns.count > 1 {
                    ForEach(0..<saleTurns.count, id: \.self) { i in
                        if i % max(1, saleTurns.count / 4) == 0 {
                            let turn = saleTurns[i]
                            let x = salePoints[i].x
                            Text("T\(turn)")
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                                .position(x: x, y: geo.size.height + 12)
                        }
                    }
                }
            }
            .frame(height: geo.size.height + 24)
        }
    }
}
