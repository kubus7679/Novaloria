import SwiftUI
import FreeColGame

struct ColonyPanelView: View {
    let colony: Colony
    let ownerName: String
    let population: Int
    let units: [FreeColGame.Unit]
    let canManage: Bool
    let selectedWorkerUnitId: String?
    let terrainFields: [ColonyTerrainField]
    var onSelectWorker: (String) -> Void
    let onChangeWorkType: (String) -> Void
    let onChangeWorkImprovementType: (String) -> Void
    let onClearSpeciality: () -> Void
    let onAssignTeacher: (String) -> Void
    let onClearTeacher: () -> Void
    let onWorkAtLocation: (String, String?) -> Void
    let onRenameColony: (String) -> Void
    let onPayForBuilding: () -> Void
    let onSetGoodsLevel: (ColonyExportData) -> Void
    let exportData: [ColonyExportData]
    let workLocationCandidates: [(id: String, label: String)]
    let buildingWorkplaces: [ColonyBuildingWorkplace]
    let teacherCandidates: [FreeColGame.Unit]
    let workTypeCandidates: [(id: String, label: String)]
    let goodsCandidates: [(id: String, label: String)]
    let workImprovementCandidates: [(id: String, label: String)]
    let onAbandonColony: () -> Void
    let canAbandonColony: Bool
    let onSetBuildQueue: ([String]) -> Void
    let onPutOutsideColony: () -> Void
    let canPutOutsideColony: Bool
    let selectedCarrierId: String?
    let selectedCarrierDescription: String?
    let carrierCandidates: [(id: String, label: String)]
    let onSelectCarrier: (String) -> Void
    let onLoadGoods: (String, Int) -> Void
    let onUnloadGoods: (String, Int) -> Void
    let maximumLoadAmount: (String) -> Int
    let maximumUnloadAmount: (String) -> Int
    let buildableCandidates: [(id: String, label: String)]
    let buildings: [(id: String, label: String)]
    let currentBuildQueue: [String]
    let buildingLabel: (String) -> String
    let storedGoods: [(id: String, label: String, amount: Int)]
    let warehouseCapacity: Int?
    let carrierGoods: [(id: String, label: String, amount: Int)]
    let buildTargetLabel: String?
    let buildRequirements: [(id: String, label: String, required: Int, stored: Int)]
    let buildPaymentCost: Int?
    let buildETATurns: Int?
    let estimatedBuildPerTurn: Int
    let estimatedProduction: [ColonyGoodsFlow]
    let efficiencyProgress: ColonyEfficiencyProgress?
    let growthETATurns: Int?
    let foodGoodsIds: Set<String>
    let availableGold: Int
    var onClaimLand: ((String, String) -> Void)?

    @State private var workTypeId: String = "model.goods.grain"
    @State private var workImprovementTypeId: String = ""
    @State private var colonyNameInput: String
    @State private var buildQueueItems: [String] = []
    @State private var selectedBuildableId: String = ""
    @State private var goodsTypeId: String = "model.goods.grain"
    @State private var goodsAmountInput: String = "10"
    @State private var showAbandonConfirmation: Bool = false
    @State private var showBuildPaymentConfirmation: Bool = false
    @State private var showWarehouse: Bool = false
    @State private var showAllGoods: Bool = false
    @State private var pendingWorkField: ColonyTerrainField?
    @State private var showBuildQueue = false
    @State private var showProductionDetails = false
    @State private var showEfficiencyDetails = false
    @State private var showWorkerActions = false
    @State private var pendingLandPurchaseTile: FreeColGame.Tile?

    init(
        colony: Colony,
        ownerName: String,
        units: [FreeColGame.Unit],
        canManage: Bool,
        selectedWorkerUnitId: String?,
        population: Int? = nil,
        terrainFields: [ColonyTerrainField] = [],
        onSelectWorker: @escaping (String) -> Void = { _ in },
        onChangeWorkType: @escaping (String) -> Void,
        onChangeWorkImprovementType: @escaping (String) -> Void,
        onClearSpeciality: @escaping () -> Void,
        onAssignTeacher: @escaping (String) -> Void,
        onClearTeacher: @escaping () -> Void,
        onWorkAtLocation: @escaping (String, String?) -> Void,
        onRenameColony: @escaping (String) -> Void,
        onPayForBuilding: @escaping () -> Void,
        onSetGoodsLevel: @escaping (ColonyExportData) -> Void,
        exportData: [ColonyExportData] = [],
        workLocationCandidates: [(id: String, label: String)] = [],
        buildingWorkplaces: [ColonyBuildingWorkplace] = [],
        teacherCandidates: [FreeColGame.Unit] = [],
        workTypeCandidates: [(id: String, label: String)] = [],
        goodsCandidates: [(id: String, label: String)]? = nil,
        workImprovementCandidates: [(id: String, label: String)] = [],
        onAbandonColony: @escaping () -> Void,
        canAbandonColony: Bool,
        onSetBuildQueue: @escaping ([String]) -> Void,
        onPutOutsideColony: @escaping () -> Void,
        canPutOutsideColony: Bool,
        selectedCarrierId: String?,
        selectedCarrierDescription: String? = nil,
        carrierCandidates: [(id: String, label: String)] = [],
        onSelectCarrier: @escaping (String) -> Void = { _ in },
        onLoadGoods: @escaping (String, Int) -> Void,
        onUnloadGoods: @escaping (String, Int) -> Void,
        maximumLoadAmount: @escaping (String) -> Int = { _ in 0 },
        maximumUnloadAmount: @escaping (String) -> Int = { _ in 0 },
        buildableCandidates: [(id: String, label: String)] = [],
        buildings: [(id: String, label: String)] = [],
        currentBuildQueue: [String] = [],
        buildingLabel: @escaping (String) -> String = { $0 },
        storedGoods: [(id: String, label: String, amount: Int)] = [],
        warehouseCapacity: Int? = nil,
        carrierGoods: [(id: String, label: String, amount: Int)] = [],
        buildTargetLabel: String? = nil,
        buildRequirements: [(id: String, label: String, required: Int, stored: Int)] = [],
        buildPaymentCost: Int? = nil,
        buildETATurns: Int? = nil,
        estimatedBuildPerTurn: Int = 0,
        estimatedProduction: [ColonyGoodsFlow] = [],
        efficiencyProgress: ColonyEfficiencyProgress? = nil,
        growthETATurns: Int? = nil,
        foodGoodsIds: Set<String> = ["model.goods.food", "model.goods.grain", "model.goods.fish"],
        availableGold: Int = 0,
        onClaimLand: ((String, String) -> Void)? = nil
    ) {
        self.colony = colony
        self.ownerName = ownerName
        self.population = population ?? colony.unitCount
        self.units = units
        self.canManage = canManage
        self.selectedWorkerUnitId = selectedWorkerUnitId
        self.terrainFields = terrainFields
        self.onSelectWorker = onSelectWorker
        self.onChangeWorkType = onChangeWorkType
        self.onChangeWorkImprovementType = onChangeWorkImprovementType
        self.onClearSpeciality = onClearSpeciality
        self.onAssignTeacher = onAssignTeacher
        self.onClearTeacher = onClearTeacher
        self.onWorkAtLocation = onWorkAtLocation
        self.onRenameColony = onRenameColony
        self.onPayForBuilding = onPayForBuilding
        self.onSetGoodsLevel = onSetGoodsLevel
        self.exportData = exportData
        self.workLocationCandidates = workLocationCandidates
        self.buildingWorkplaces = buildingWorkplaces
        self.teacherCandidates = teacherCandidates
        self.workTypeCandidates = workTypeCandidates
        self.goodsCandidates = goodsCandidates ?? workTypeCandidates
        self.workImprovementCandidates = workImprovementCandidates
        self.onAbandonColony = onAbandonColony
        self.canAbandonColony = canAbandonColony
        self.onSetBuildQueue = onSetBuildQueue
        self.onPutOutsideColony = onPutOutsideColony
        self.canPutOutsideColony = canPutOutsideColony
        self.selectedCarrierId = selectedCarrierId
        self.selectedCarrierDescription = selectedCarrierDescription
        self.carrierCandidates = carrierCandidates
        self.onSelectCarrier = onSelectCarrier
        self.onLoadGoods = onLoadGoods
        self.onUnloadGoods = onUnloadGoods
        self.maximumLoadAmount = maximumLoadAmount
        self.maximumUnloadAmount = maximumUnloadAmount
        self.buildableCandidates = buildableCandidates
        self.buildings = buildings
        self.currentBuildQueue = currentBuildQueue
        self.buildingLabel = buildingLabel
        self.storedGoods = storedGoods
        self.warehouseCapacity = warehouseCapacity
        self.carrierGoods = carrierGoods
        self.buildTargetLabel = buildTargetLabel
        self.buildRequirements = buildRequirements
        self.buildPaymentCost = buildPaymentCost
        self.buildETATurns = buildETATurns
        self.estimatedBuildPerTurn = estimatedBuildPerTurn
        self.estimatedProduction = estimatedProduction
        self.efficiencyProgress = efficiencyProgress
        self.growthETATurns = growthETATurns
        self.foodGoodsIds = foodGoodsIds
        self.availableGold = availableGold
        self.onClaimLand = onClaimLand
        _colonyNameInput = State(initialValue: colony.name ?? "")
        _buildQueueItems = State(initialValue: currentBuildQueue)
        _selectedBuildableId = State(initialValue: buildableCandidates.first?.id ?? "")
        _workTypeId = State(initialValue: workTypeCandidates.first?.id ?? "")
        _goodsTypeId = State(initialValue: (goodsCandidates ?? workTypeCandidates).first?.id ?? "")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                statusBar
                if geometry.size.width >= 980 && geometry.size.height >= 560 {
                    HStack(alignment: .top, spacing: 10) {
                        ScrollView {
                            VStack(spacing: 10) {
                                terrainCard
                                foodSummaryCard
                                constructionCard
                            }
                        }
                        .frame(width: 320)
                        ScrollView { buildingWorkplacesCard }
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier("colony-workspace")
                    alignedTransportRow
                    warehouseCard
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            terrainCard
                            foodSummaryCard
                            constructionCard
                            buildingWorkplacesCard
                            transportRow
                            warehouseCard
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .accessibilityIdentifier("colony-dashboard")
        .confirmationDialog(
            L10n.text("Diese Kolonie verlassen?", table: "ColonyPanelView"),
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Kolonie verlassen", table: "ColonyPanelView"), role: .destructive) {
                onAbandonColony()
            }
            Button(L10n.text("Abbrechen", table: "ColonyPanelView"), role: .cancel) {}
        } message: {
            Text(L10n.text("Die Kolonie wird unwiderruflich entfernt.", table: "ColonyPanelView"))
        }
        .alert(
            L10n.text("Bau bezahlen?", table: "ColonyPanelView"),
            isPresented: $showBuildPaymentConfirmation
        ) {
            Button(L10n.text("Ja", table: "ColonyPanelView")) {
                onPayForBuilding()
            }
            Button(L10n.text("Nein", table: "ColonyPanelView"), role: .cancel) {}
        } message: {
            if let buildPaymentCost {
                Text(L10n.text("Möchtest du \(buildPaymentCost.formatted(.number.locale(Locale(identifier: "de_DE")))) Gold bezahlen, um den Bau abzuschließen?", table: "ColonyPanelView"))
            } else {
                Text(L10n.text("Der zu zahlende Goldbetrag konnte nicht ermittelt werden. Möchtest du den Bau trotzdem bezahlen?", table: "ColonyPanelView"))
            }
        }
        .sheet(isPresented: $showWarehouse) {
            WarehouseSheet(exportData: exportData, onApply: onSetGoodsLevel)
        }
        .sheet(item: $pendingLandPurchaseTile) { tile in
            NativeLandPurchaseSheet(tile: tile, availableGold: availableGold) { offer in
                onClaimLand?(tile.id, offer)
            }
        }
        .onAppear {
            syncWorkerInputs()
            syncGoodsInput()
        }
        .onChange(of: selectedWorkerUnitId) { _, _ in
            syncWorkerInputs()
            showWorkerActions = false
        }
        .onChange(of: workTypeCandidates.map(\.id)) { _, _ in syncWorkerInputs() }
        .onChange(of: workImprovementCandidates.map(\.id)) { _, _ in syncWorkerInputs() }
        .onChange(of: selectedCarrierId) { _, _ in syncGoodsInput() }
        .onChange(of: transferGoodsCandidates.map(\.id)) { _, _ in syncGoodsInput() }
        .onChange(of: colony.name) { _, name in colonyNameInput = name ?? "" }
        .onChange(of: colony.buildQueue) { _, newQueue in
            // Keep the draft in sync with server-driven queue changes.
            buildQueueItems = newQueue
        }
    }

    private var statusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                metricBadge(L10n.text("Bevölkerung", table: "ColonyPanelView"), value: "\(population)", systemImage: "person.2")
                    .help(L10n.text("Einwohner der Kolonie: \(population). Serverstand: \(colony.unitCount). Bekannte Innenarbeitsplätze werden mitgezählt; Einheiten vor der Kolonie und an Bord zählen nicht dazu.", table: "ColonyPanelView"))
                metricBadge(L10n.text("Freiheitsstreben", table: "ColonyPanelView"), value: "\(colony.sonsOfLiberty)%", systemImage: "flag")
                    .help(L10n.text("Vom Server berechneter Anteil der Freiheitsanhänger. Gespeicherte Freiheit: \(colony.liberty). Dieser Anteil ist kein direkter Prozentbonus auf die Produktion.", table: "ColonyPanelView"))
                metricBadge(L10n.text("Produktionsbonus", table: "ColonyPanelView"), value: signed(colony.productionBonus), systemImage: "plusminus")
                    .help(L10n.text("Vom Server bestimmter additiver Koloniebonus, kein Prozentwert. Seine Wirkung hängt vom Arbeitsplatz und den Regeln der Spezifikation ab; der Produktionstooltip zeigt die tatsächlich angewandten Boni.", table: "ColonyPanelView"))
                efficiencyBadge
                administrationDetails
            }
        }
        .frame(height: 38)
    }

    private var administrationDetails: some View {
        HStack(spacing: 8) {
            metricBadge(L10n.text("Besitzer", table: "ColonyPanelView"), value: ownerName, systemImage: "person")
            metricBadge(L10n.text("Freiheit", table: "ColonyPanelView"), value: "\(colony.liberty)", systemImage: "flag")
            metricBadge(L10n.text("Einwanderung", table: "ColonyPanelView"), value: "\(colony.immigration)", systemImage: "figure.walk")
            metricBadge(L10n.text("Gegründet", table: "ColonyPanelView"), value: "\(colony.established)", systemImage: "calendar")

            TextField(L10n.text("Koloniename", table: "ColonyPanelView"), text: $colonyNameInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .accessibilityIdentifier("colony-name")
                .onSubmit { if canRename { onRenameColony(colonyNameInput) } }
            Button(L10n.text("Umbenennen", table: "ColonyPanelView")) {
                onRenameColony(colonyNameInput)
            }
            .disabled(!canRename)
            .controlSize(.small)
            .accessibilityIdentifier("colony-rename")

            if canManage && canAbandonColony {
                Button(L10n.text("Kolonie verlassen…", table: "ColonyPanelView"), role: .destructive) {
                    showAbandonConfirmation = true
                }
                .accessibilityIdentifier("colony-abandon")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("colony-administration")
    }

    private var efficiencyBadge: some View {
        let badgeValue: String
        if let progress = efficiencyProgress {
            if let bonus = progress.nextProductionBonus,
               let liberty = progress.libertyUntilNextBonus {
                badgeValue = L10n.text("\(signed(bonus)) · \(liberty) 🔔", table: "ColonyPanelView")
            } else if progress.currentProductionBonus >= 2 {
                badgeValue = L10n.text("Maximal", table: "ColonyPanelView")
            } else {
                badgeValue = "—"
            }
        } else {
            badgeValue = "—"
        }

        return Button {
            showEfficiencyDetails = true
        } label: {
            metricBadge(L10n.text("Nächster Bonus", table: "ColonyPanelView"),
                        value: badgeValue, systemImage: "bell")
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEfficiencyDetails) {
            efficiencyDetails.padding(12).frame(width: 340)
        }
        .help(L10n.text("Effizienz und Glockenbedarf bis zur nächsten Stufe anzeigen.", table: "ColonyPanelView"))
        .accessibilityIdentifier("colony-efficiency-progress")
    }

    @ViewBuilder
    private var efficiencyDetails: some View {
        if let progress = efficiencyProgress {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Effizienz nach Kolonistenzahl", table: "ColonyPanelView"))
                    .font(.headline)
                ForEach(progress.populationBands) { band in
                    HStack {
                        Text(populationBandLabel(band))
                        Spacer(minLength: 12)
                        Text(signed(band.productionBonus))
                            .fontWeight(.semibold)
                    }
                    .font(.callout.monospacedDigit())
                }
                Divider()
                if let nextBonus = progress.nextProductionBonus,
                   let bellsNeeded = progress.libertyUntilNextBonus {
                    Text(L10n.text("Nächste Stufe: Produktionsbonus \(signed(nextBonus))", table: "ColonyPanelView"))
                        .font(.callout.weight(.semibold))
                    Text(L10n.text(
                        "Noch \(bellsNeeded) Glocken bis zur nächsten Stufe (Freiheit \(progress.currentLiberty) → \(progress.currentLiberty + bellsNeeded)).",
                        table: "ColonyPanelView"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("Glockenproduktion pro Runde: \(progress.bellsPerTurn)", table: "ColonyPanelView"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.text("Keine weitere Effizienzstufe.", table: "ColonyPanelView"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(L10n.text(
                    "Der Kolonistenvergleich hält die aktuelle Glockenzahl konstant. Der Produktionsbonus ist additiv und wird je Arbeitsplatz unterschiedlich angewandt.",
                    table: "ColonyPanelView"
                ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .monospacedDigit()
        } else {
            Text(L10n.text("Keine Effizienzprognose verfügbar.", table: "ColonyPanelView"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func populationBandLabel(_ band: ColonyEfficiencyPopulationBand) -> String {
        if band.minimumPopulation == band.maximumPopulation {
            return L10n.text("Bei \(band.minimumPopulation) Kolonisten", table: "ColonyPanelView")
        }
        return L10n.text("Bei \(band.minimumPopulation)–\(band.maximumPopulation) Kolonisten", table: "ColonyPanelView")
    }

    private var foodFlows: [ColonyGoodsFlow] {
        estimatedProduction.filter { foodGoodsIds.contains($0.id) }
    }

    private var foodNet: Int { foodFlows.reduce(0) { $0 + $1.net } }

    private var foodBalance: ColonyGoodsFlow? {
        guard !foodFlows.isEmpty else { return nil }
        let produced = foodFlows.reduce(0) { $0 + $1.produced }
        let consumed = foodFlows.reduce(0) { $0 + $1.consumed }
        return ColonyGoodsFlow(
            id: "model.goods.food", label: GameLabels.name("model.goods.food"),
            produced: produced, consumed: consumed,
            explanation: ([L10n.text("Nahrungsbilanz aus allen Nahrungsquellen: \(produced) − \(consumed) = \(produced - consumed).", table: "ColonyPanelView")]
                          + foodFlows.map(\.explanation)).joined(separator: "\n")
        )
    }

    var growthExplanation: String {
        let stock = colony.goods["model.goods.food", default: 0]
        let threshold = ColonyProductionCalculator.foodPerColonistForGrowth
        let formula = L10n.text("Nahrungsvorrat: \(stock). Wachstumsgrenze: \(threshold). Nahrungsbilanz pro Runde: \(foodNet).", table: "ColonyPanelView")
        let rule = L10n.text("Wenn Vorrat plus nächste Bilanz die Grenze erreicht, wächst die Kolonie nächste Runde. Sonst: (Grenze − Vorrat) / positive Bilanz, abgerundet, plus eine Runde. Ohne Überschuss ist keine Wachstumszeit bestimmbar.", table: "ColonyPanelView")
        return ([formula, rule] + foodFlows.map(\.explanation) + [ColonyProductionCalculator.projectionNotice])
            .joined(separator: "\n")
    }

    private var foodSummaryCard: some View {
        panelCard(L10n.text("Nahrung und Wachstum", table: "ColonyPanelView"), systemImage: "leaf") {
            LabeledContent(L10n.text("Vorrat", table: "ColonyPanelView"), value: "\(colony.goods["model.goods.food", default: 0])")
                .help(L10n.text("Gelagerte Nahrung laut Server. Erzeugtes Getreide und Fisch fließen über die Nahrungsbilanz in diesen Vorrat ein.", table: "ColonyPanelView"))
            if estimatedProduction.isEmpty {
                Text(L10n.text("Keine Produktionsvorhersage verfügbar.", table: "ColonyPanelView"))
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent(L10n.text("Produktion", table: "ColonyPanelView"), value: "+\(foodFlows.reduce(0) { $0 + $1.produced })")
                LabeledContent(L10n.text("Verbrauch", table: "ColonyPanelView"), value: "−\(foodFlows.reduce(0) { $0 + $1.consumed })")
                LabeledContent(L10n.text("Bilanz pro Runde", table: "ColonyPanelView")) {
                    Text(signed(foodNet)).foregroundStyle(foodNet < 0 ? .orange : .green)
                }
                Divider()
                Text(growthETATurns.map {
                    L10n.text("Wachstum in etwa \($0) Runden", table: "ColonyPanelView")
                } ?? L10n.text("Keine Wachstumsprognose.", table: "ColonyPanelView"))
                .accessibilityIdentifier("colony-growth-eta")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .help(growthExplanation)
        .accessibilityIdentifier("colony-food-summary")
    }

    private var constructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if buildTargetLabel != nil {
                currentBuildCard
            } else {
                panelCard(L10n.text("Aktueller Bauauftrag", table: "ColonyPanelView"), systemImage: "hammer") {
                    Text(L10n.text("Keine Bauliste festgelegt.", table: "ColonyPanelView"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(currentBuildQueue.dropFirst().map(buildingLabel).joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    .help(currentBuildQueue.map(buildingLabel).joined(separator: "\n"))
                Spacer(minLength: 0)
                Button(L10n.text("Bauliste…", table: "ColonyPanelView")) { showBuildQueue = true }
                    .controlSize(.small)
                    .popover(isPresented: $showBuildQueue) {
                        nextBuildQueueCard.padding(10).frame(width: 390, height: 440)
                    }
                    .accessibilityIdentifier("colony-build-queue")
            }
        }
    }

    private var alignedTransportRow: some View {
        HStack(alignment: .top, spacing: 10) {
            unassignedWorkersRow.frame(width: 320, alignment: .leading)
            freightCard.frame(minWidth: 480)
        }
    }

    private var transportRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                unassignedWorkersRow.frame(width: 220, alignment: .leading)
                freightCard.frame(minWidth: 480)
            }
            VStack(alignment: .leading, spacing: 8) {
                unassignedWorkersRow
                freightCard
            }
        }
    }

    private var freightCard: some View {
        panelCard(L10n.text("Hafen und Transport", table: "ColonyPanelView"), systemImage: "ferry") {
            if let selectedCarrierId {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        carrierOverview.frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                        if !transferGoodsCandidates.isEmpty {
                            transferControls.frame(width: 300)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        carrierOverview
                        if !transferGoodsCandidates.isEmpty {
                            transferControls.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .accessibilityIdentifier("colony-carrier-\(selectedCarrierId)")
            } else {
                Text(L10n.text("Frachtaktionen werden angezeigt, wenn ein Transporter ausgewählt ist.", table: "ColonyPanelView"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .controlSize(.small)
    }

    private var carrierOverview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if carrierCandidates.count > 1 {
                Picker(L10n.text("Frachter", table: "ColonyPanelView"), selection: Binding(
                    get: { selectedCarrierId ?? "" }, set: onSelectCarrier
                )) {
                    ForEach(carrierCandidates, id: \.id) { Text($0.label).tag($0.id) }
                }
                .accessibilityIdentifier("colony-carrier-picker")
            } else if let selectedCarrierDescription {
                Text(selectedCarrierDescription).font(.caption).lineLimit(2)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if carrierGoods.isEmpty {
                        Text(L10n.text("Der Transporter ist leer.", table: "ColonyPanelView"))
                            .foregroundStyle(.secondary).font(.caption)
                    }
                    ForEach(carrierGoods, id: \.id) { item in
                        HStack(spacing: 4) {
                            goodsIcon(item.id, size: 22)
                            Text("\(item.amount)").monospacedDigit()
                        }
                        .font(.caption).padding(5)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                        .help("\(item.label): \(item.amount)")
                    }
                }
            }
        }
    }

    private var transferControls: some View {
        let loadMaximum = maximumLoadAmount(goodsTypeId)
        let unloadMaximum = maximumUnloadAmount(goodsTypeId)
        return VStack(alignment: .leading, spacing: 5) {
            Picker(L10n.text("Ware", table: "ColonyPanelView"), selection: $goodsTypeId) {
                ForEach(transferGoodsCandidates, id: \.id) { Text($0.label).tag($0.id) }
            }
            HStack(spacing: 6) {
                TextField(L10n.text("Menge", table: "ColonyPanelView"), text: $goodsAmountInput)
                    .textFieldStyle(.roundedBorder).frame(width: 65)
                    .accessibilityIdentifier("colony-transfer-amount")
                if loadMaximum > 0 {
                    Button(L10n.text("Laden", table: "ColonyPanelView")) {
                        if let amount = Int(goodsAmountInput) { onLoadGoods(goodsTypeId, amount) }
                    }
                    .disabled(!canManage || !validTransferAmount(maximum: loadMaximum))
                }
                if unloadMaximum > 0 {
                    Button(L10n.text("Entladen", table: "ColonyPanelView")) {
                        if let amount = Int(goodsAmountInput) { onUnloadGoods(goodsTypeId, amount) }
                    }
                    .disabled(!canManage || !validTransferAmount(maximum: unloadMaximum))
                }
            }
            HStack(spacing: 6) {
                if loadMaximum > 0 {
                    Button(L10n.text("Max laden: \(loadMaximum)", table: "ColonyPanelView")) {
                        goodsAmountInput = "\(loadMaximum)"
                    }
                }
                if unloadMaximum > 0 {
                    Button(L10n.text("Max entladen: \(unloadMaximum)", table: "ColonyPanelView")) {
                        goodsAmountInput = "\(unloadMaximum)"
                    }
                }
            }
            .font(.caption2)
        }
        .help(L10n.text("Laden ist durch Lagerbestand und freien Laderaum begrenzt; Entladen durch die vorhandene Fracht. Die Max-Schaltflächen übernehmen die aktuell mögliche Menge.", table: "ColonyPanelView"))
    }

    private var warehouseCard: some View {
        panelCard(L10n.text("Lager und Bilanz", table: "ColonyPanelView"), systemImage: "shippingbox") {
            HStack(spacing: 12) {
                Toggle(L10n.text("Auch Waren mit Bestand 0 anzeigen", table: "ColonyPanelView"), isOn: $showAllGoods)
                    .toggleStyle(.checkbox).font(.caption2)
                Spacer(minLength: 0)
                Button(L10n.text("Produktionsdetails…", table: "ColonyPanelView")) { showProductionDetails = true }
                    .popover(isPresented: $showProductionDetails) {
                        ScrollView { colonyProductionSummaryCard.padding(10) }.frame(width: 660, height: 400)
                    }
                    .accessibilityIdentifier("colony-production-details")
                if canManage && !exportData.isEmpty {
                    Button(L10n.text("Export- und Importregeln…", table: "ColonyPanelView")) { showWarehouse = true }
                }
            }
            .controlSize(.small)
            if let warehouseCapacity {
                LabeledContent(
                    L10n.text("Maximale Lagerkapazität je Ware", table: "ColonyPanelView"),
                    value: warehouseCapacity.formatted(
                        .number.locale(LocalizationSettings.shared.language.locale)
                    )
                )
                .font(.caption)
                .monospacedDigit()
                .help(L10n.text(
                    "Die Kapazität gilt je Warenart. Sie ergibt sich aus den Lagerkapazitätsboni der gebauten Gebäude.",
                    table: "ColonyPanelView"
                ))
                .accessibilityIdentifier("colony-warehouse-capacity")
            }
            ScrollView {
                if visibleGoods.isEmpty {
                    Text(L10n.text("Keine gelagerten Waren.", table: "ColonyPanelView"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), alignment: .leading)], spacing: 6) {
                    ForEach(visibleGoods, id: \.id) { item in
                        warehouseGoods(item)
                    }
                }
            }
            .frame(height: visibleGoods.count > 8 ? 94 : 49)
        }
        .accessibilityIdentifier("colony-warehouse")
    }

    private func warehouseGoods(_ item: (id: String, label: String, amount: Int)) -> some View {
        let flow = item.id == "model.goods.food" ? foodBalance : estimatedProduction.first { $0.id == item.id }
        return HStack(spacing: 6) {
            goodsIcon(item.id, size: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 5) {
                    Text("\(item.amount)").font(.callout.weight(.semibold))
                    if let flow {
                        Text(signed(flow.net)).font(.caption2)
                            .foregroundStyle(flow.net < 0 ? .orange : .green)
                    }
                }
                .monospacedDigit()
            }
        }
        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .help(L10n.text("Lagerbestand vom Server: \(item.amount) \(item.label).", table: "ColonyPanelView")
              + "\n" + (flow?.explanation ?? L10n.text("Keine Produktionsvorhersage verfügbar.", table: "ColonyPanelView")))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("colony-goods-\(item.id)")
    }

    private func goodsIcon(_ goodsType: String, size: CGFloat) -> some View {
        Group {
            if let image = TileImageCache.shared.goodsImage(for: goodsType) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "shippingbox")
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private var canRename: Bool {
        let name = colonyNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return canManage && !name.isEmpty
            && name.caseInsensitiveCompare(colony.name ?? "") != .orderedSame
    }

    private var selectedWorker: FreeColGame.Unit? {
        guard let selectedWorkerUnitId else { return nil }
        return units.first { $0.id == selectedWorkerUnitId }
    }

    private var hasSelectedWorkerActions: Bool {
        guard let selectedWorker else { return false }
        return workTypeCandidates.count > 1
            || !workImprovementCandidates.isEmpty
            || (selectedWorker.role != nil && selectedWorker.role != "model.role.default")
            || canPutOutsideColony
    }

    @ViewBuilder
    private var selectedWorkerContextMenu: some View {
        if let selectedWorker {
            let otherWorkers = teacherCandidates.filter { $0.id != selectedWorker.id }
            if !otherWorkers.isEmpty {
                Menu(L10n.text("Lehrer zuweisen", table: "ColonyPanelView")) {
                    ForEach(otherWorkers, id: \.id) { candidate in
                        Button(candidate.unitType.map(GameLabels.name) ?? L10n.text("Einheit", table: "ColonyPanelView")) {
                            onAssignTeacher(candidate.id)
                        }
                        .disabled(!canManage || !selectedWorkerIsWorking)
                    }
                    if !selectedWorkerIsWorking {
                        Text(L10n.text(
                            "Der Schüler muss zuerst in einem Gebäude oder auf einem Feld arbeiten.",
                            table: "ColonyPanelView"
                        ))
                    }
                }
            } else {
                Text(L10n.text("Kein freier Lehrer verfügbar", table: "ColonyPanelView"))
            }

            if let teacherId = selectedWorker.teacher,
               let teacher = units.first(where: { $0.id == teacherId }) {
                Text(L10n.text(
                    "Aktueller Lehrer: \(teacher.unitType.map(GameLabels.name) ?? L10n.text("Einheit", table: "ColonyPanelView"))",
                    table: "ColonyPanelView"
                ))
                Button(L10n.text("Lehrer entfernen", table: "ColonyPanelView"), action: onClearTeacher)
                    .disabled(!canManage)
            }

            if hasSelectedWorkerActions {
                Button(L10n.text("Weitere Aktionen", table: "ColonyPanelView")) {
                    showWorkerActions = true
                }
            }
        }
    }

    private var selectedWorkerIsWorking: Bool {
        guard let selectedWorker else { return false }
        return colony.buildings.contains { $0.id == selectedWorker.location }
            || colony.workTiles.contains { $0.id == selectedWorker.location }
    }

    private var terrainCard: some View {
        panelCard(L10n.text("Koloniegelände", table: "ColonyPanelView"), systemImage: "map") {
            if terrainFields.isEmpty {
                Text(L10n.text("Keine Felder verfügbar.", table: "ColonyPanelView"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ColonyTerrainView(
                    fields: terrainFields,
                    selectedWorkerId: selectedWorkerUnitId,
                    canManage: canManage,
                    onAssign: { onWorkAtLocation($0, nil) },
                    onSelectWorker: onSelectWorker,
                    onSelectField: selectWorkField,
                    onClaimLand: { field in pendingLandPurchaseTile = field.tile },
                    showsHeader: false,
                    showsInstructions: false,
                    onDropWorker: dropWorkerOnField,
                    workerContextMenu: { workerId in
                        if workerId == selectedWorkerUnitId {
                            AnyView(selectedWorkerContextMenu)
                        } else {
                            AnyView(EmptyView())
                        }
                    }
                )
                .help(L10n.text("Arbeiter auswählen, dann ein Feld anklicken. Ein belegtes Feld tauscht die Arbeiter.", table: "ColonyTerrainView"))
                .sheet(item: $pendingWorkField) { field in
                    ColonyFieldProductionChooser(field: field) { goodsType in
                        guard let locationId = field.workLocationId else { return }
                        onWorkAtLocation(locationId, goodsType)
                        pendingWorkField = nil
                    }
                }
            }
        }
    }

    private var unassignedWorkers: [FreeColGame.Unit] {
        let visibleLocations = Set(buildingWorkplaces.map(\.id))
            .union(terrainFields.filter { $0.offset != .zero }.compactMap(\.workLocationId))
        return units.filter { unit in
            guard let location = unit.location else { return true }
            return !visibleLocations.contains(location)
        }
    }

    private var unassignedWorkersRow: some View {
        Group {
            if !unassignedWorkers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Ohne sichtbaren Arbeitsplatz", table: "ColonyPanelView"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(unassignedWorkers) { worker in
                                workerSelectionChip(worker)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func workerSelectionChip(_ worker: FreeColGame.Unit) -> some View {
        Button {
            onSelectWorker(worker.id)
        } label: {
            HStack(spacing: 6) {
                if let image = TileImageCache.shared.unitImage(
                    forUnitType: worker.unitType, role: worker.role
                ) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 30)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "person.fill")
                }
                Text(worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyPanelView"))
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                worker.id == selectedWorkerUnitId
                    ? Color.accentColor.opacity(0.2)
                    : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canManage)
        .draggable(worker.id)
        .contextMenu {
            if worker.id == selectedWorkerUnitId {
                selectedWorkerContextMenu
            }
        }
        .help(worker.id == selectedWorkerUnitId
            ? L10n.text("Rechtsklick für Ausbildungsaktionen", table: "ColonyPanelView")
            : L10n.text("\(worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyPanelView")) auswählen", table: "ColonyPanelView"))
        .accessibilityIdentifier("colony-unassigned-worker-\(worker.id)")
    }

    @ViewBuilder
    private var selectedWorkerActions: some View {
        if let selectedWorker, hasSelectedWorkerActions {
            VStack(alignment: .leading, spacing: 8) {
                if workTypeCandidates.count > 1 {
                    HStack(spacing: 8) {
                        Picker(L10n.text("Produktion", table: "ColonyPanelView"), selection: $workTypeId) {
                            ForEach(workTypeCandidates, id: \.id) { candidate in
                                Text(candidate.label).tag(candidate.id)
                            }
                        }
                        .disabled(!canManage)
                        Button(L10n.text("Ändern", table: "ColonyPanelView")) { onChangeWorkType(workTypeId) }
                            .buttonStyle(.bordered)
                            .disabled(!canManage || !workTypeCandidates.contains { $0.id == workTypeId })
                    }
                }

                if !workImprovementCandidates.isEmpty {
                    HStack(spacing: 8) {
                        Picker(L10n.text("Verbesserung", table: "ColonyPanelView"), selection: $workImprovementTypeId) {
                            ForEach(workImprovementCandidates, id: \.id) { candidate in
                                Text(candidate.label).tag(candidate.id)
                            }
                        }
                        .disabled(!canManage)
                        Button(L10n.text("Ändern", table: "ColonyPanelView")) {
                            onChangeWorkImprovementType(workImprovementTypeId)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            !canManage
                                || !workImprovementCandidates.contains {
                                    $0.id == workImprovementTypeId
                                })
                    }
                }

                if selectedWorker.role != nil && selectedWorker.role != "model.role.default" {
                    Button(L10n.text("Spezialisierung löschen", table: "ColonyPanelView"), action: onClearSpeciality)
                        .buttonStyle(.bordered)
                        .disabled(!canManage)
                }
                if canPutOutsideColony {
                    Button(L10n.text("Vor die Kolonie stellen", table: "ColonyPanelView"), action: onPutOutsideColony)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var buildingWorkLocationCandidates: [(id: String, label: String)] {
        let buildingIds = Set(colony.buildings.map(\.id))
        return workLocationCandidates.filter { buildingIds.contains($0.id) }
    }

    private var buildingWorkplacesCard: some View {
        let occupied = buildingWorkplaces.reduce(0) { $0 + $1.workers.count }
        let capacity = buildingWorkplaces.reduce(0) { $0 + $1.capacity }
        let assignableBuildingIds = Set(buildingWorkLocationCandidates.map(\.id))

        return panelCard(L10n.text("Gebäude", table: "ColonyPanelView"), systemImage: "building.2") {
            if buildingWorkplaces.isEmpty {
                if buildings.isEmpty {
                    Text(L10n.text("In dieser Kolonie gibt es noch keine Gebäude.", table: "ColonyPanelView"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(buildings, id: \.id) { building in
                        Label(building.label, systemImage: "building.2.crop.circle")
                            .font(.callout)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text(L10n.text("\(occupied) von \(capacity) Arbeitsplätzen belegt", table: "ColonyPanelView"))
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), alignment: .top)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(buildingWorkplaces) { workplace in
                        buildingWorkplaceCard(
                            workplace,
                            canAssign: canManage
                                && selectedWorker != nil
                                && assignableBuildingIds.contains(workplace.id)
                                && !workplace.workers.contains { $0.id == selectedWorker?.id }
                        )
                    }
                }
            }
        }
        .popover(isPresented: $showWorkerActions) {
            selectedWorkerActions.padding(12).frame(width: 380)
        }
    }

    private func buildingWorkplaceCard(
        _ workplace: ColonyBuildingWorkplace,
        canAssign: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let entry = ColopediaCatalog.classicEntries.first(where: {
                    $0.id == workplace.buildingTypeId && $0.category == .buildings
                }), let image = TileImageCache.shared.colopediaImage(for: entry) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "building.2.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workplace.label)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(L10n.text("\(workplace.workers.count)/\(workplace.capacity) Arbeiter", table: "ColonyPanelView"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help(L10n.text("Belegte Arbeitsplätze: \(workplace.workers.count). Kapazität dieses Gebäudes laut Spezifikation: \(workplace.capacity).", table: "ColonyPanelView"))
                }
                Spacer(minLength: 0)
            }
            .frame(height: 44, alignment: .leading)
            .help(workplace.label)

            Group {
                if let goodsTypeId = workplace.goodsTypeId {
                    HStack(spacing: 6) {
                        if let image = TileImageCache.shared.goodsImage(for: goodsTypeId) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        Text(L10n.text("+\(workplace.productionPerTurn) / Runde", table: "ColonyPanelView"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(workplace.productionPerTurn > 0 ? .green : .secondary)
                            .fixedSize()
                    }
                    .help(workplace.productionExplanation)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L10n.text(
                        "\(GameLabels.name(goodsTypeId)), \(workplace.productionPerTurn) pro Runde",
                        table: "ColonyPanelView"
                    ))
                } else if workplace.isTeachingBuilding {
                    Label(L10n.text("Ausbildung", table: "ColonyPanelView"), systemImage: "graduationcap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.text("Keine aktive Produktion", table: "ColonyPanelView"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 26, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(workplace.workers) { worker in
                        Button {
                            onSelectWorker(worker.id)
                        } label: {
                            HStack(spacing: 4) {
                                if let image = TileImageCache.shared.unitImage(
                                    forUnitType: worker.unitType, role: worker.role
                                ) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 25, height: 30)
                                        .accessibilityHidden(true)
                                } else {
                                    Image(systemName: "person.fill")
                                        .frame(width: 25, height: 25)
                                }
                                if let progress = workplace.educationProgress.first(where: {
                                    $0.id == worker.id
                                }) {
                                    Text("\(progress.remainingTurns)")
                                        .font(.system(size: 9).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                worker.id == selectedWorkerUnitId
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.secondary.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canManage)
                        .draggable(worker.id)
                        .contextMenu {
                            if worker.id == selectedWorkerUnitId {
                                selectedWorkerContextMenu
                            }
                        }
                        .help(buildingWorkerHelp(worker, workplace: workplace))
                        .accessibilityLabel(worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyPanelView"))
                        .accessibilityIdentifier("colony-building-worker-\(worker.id)")
                    }

                    if workplace.workers.count < workplace.capacity {
                        let freeSlots = workplace.capacity - workplace.workers.count
                        Button {
                            onWorkAtLocation(workplace.id, workplace.goodsTypeId)
                        } label: {
                            Label("\(freeSlots)", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canAssign)
                        .help(canAssign
                            ? L10n.text("Ausgewählten Arbeiter diesem Gebäude zuweisen", table: "ColonyPanelView")
                            : L10n.text("Wählen Sie einen geeigneten Arbeiter aus; freie Plätze: \(freeSlots)", table: "ColonyPanelView"))
                        .accessibilityLabel(L10n.text("Ausgewählten Arbeiter diesem Gebäude zuweisen", table: "ColonyPanelView"))
                        .accessibilityIdentifier("colony-building-assign-\(workplace.id)")
                    } else if workplace.capacity == 0 {
                        Text(L10n.text("Keine Arbeiterplätze", table: "ColonyPanelView"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 34, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 142, alignment: .topLeading)
        .background(
            Color(NSColor.controlBackgroundColor).opacity(0.48),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityIdentifier("colony-building-\(workplace.id)")
        .dropDestination(for: String.self) { items, _ in
            guard items.count == 1 else { return false }
            return dropWorker(items[0], in: workplace)
        }
    }

    private func buildingWorkerHelp(_ worker: FreeColGame.Unit, workplace: ColonyBuildingWorkplace) -> String {
        let name = worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyPanelView")
        guard let progress = workplace.educationProgress.first(where: { $0.id == worker.id }) else {
            return L10n.text("\(name) auswählen", table: "ColonyPanelView")
        }
        return name + "\n" + L10n.text("Schüler: \(GameLabels.name(progress.studentUnitTypeId)). Bisherige Ausbildung: \(worker.turnsOfTraining) Runden. Rest: \(progress.remainingTurns) Runden (Spezifikationsdauer minus bisherige Runden, mindestens eine Runde).", table: "ColonyPanelView")
    }

    var buildExplanation: String {
        let requirements = buildRequirements.map { item in
            L10n.text("\(item.label): benötigt \(item.required), vorhanden \(item.stored), fehlend \(max(0, item.required - item.stored)).", table: "ColonyPanelView")
        }
        let rule = L10n.text("Die Bauzeit verwendet fehlende Bauhämmer geteilt durch \(estimatedBuildPerTurn) Bauhämmer pro Runde, aufgerundet. Andere Materialien, Lieferungen und spätere Änderungen können den Abschluss verzögern.", table: "ColonyPanelView")
        let production = estimatedProduction.first { $0.id == "model.goods.hammers" }?.explanation
        return (requirements + [rule] + [production].compactMap { $0 } + [ColonyProductionCalculator.projectionNotice])
            .joined(separator: "\n")
    }

    private var currentBuildCard: some View {
        panelCard(
            buildTargetLabel == nil ? L10n.text("Produktion", table: "ColonyPanelView") : L10n.text("Aktueller Bauauftrag", table: "ColonyPanelView"),
            systemImage: "hammer"
        ) {
            if let target = buildTargetLabel {
                Text(target)
                    .font(.callout.weight(.medium))
                ForEach(buildRequirements, id: \.id) { requirement in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(requirement.label)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(requirement.stored)/\(requirement.required)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .help(L10n.text("\(requirement.label): benötigt \(requirement.required), vorhanden \(requirement.stored), fehlend \(max(0, requirement.required - requirement.stored)).", table: "ColonyPanelView"))
                        ProgressView(
                            value: requirement.required > 0
                                ? min(1.0, Double(requirement.stored) / Double(requirement.required))
                                : 1.0
                        )
                    }
                }
                HStack {
                    Text(L10n.text("Bauhämmer pro Runde", table: "ColonyPanelView"))
                    Spacer(minLength: 4)
                    Text(estimatedProduction.isEmpty ? "—" : "\(estimatedBuildPerTurn)")
                        .monospacedDigit()
                }
                .font(.caption)
                .help(estimatedProduction.first { $0.id == "model.goods.hammers" }?.explanation
                      ?? L10n.text("Keine Produktionsvorhersage verfügbar.", table: "ColonyPanelView"))
                if let eta = buildETATurns {
                    Text(eta == 0
                         ? L10n.text("Fertig in der nächsten Runde", table: "ColonyPanelView")
                         : L10n.text("Noch etwa \(eta) Runden", table: "ColonyPanelView"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(buildExplanation)
                }
                if canManage {
                    Button(L10n.text("Bau bezahlen", table: "ColonyPanelView")) {
                        showBuildPaymentConfirmation = true
                    }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("colony-pay-for-building")
                        .help(L10n.text("Kostenschätzung für fehlende Waren: lagerbare Waren zum Markt-Kaufpreis mit 10 % Aufschlag, andere Waren zum Spezifikationspreis. Der Server bestätigt die Zahlung.", table: "ColonyPanelView"))
                }
            }

        }
    }

    private var colonyProductionSummaryCard: some View {
        panelCard(L10n.text("Nahrung und Produktion", table: "ColonyPanelView"), systemImage: "chart.bar") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(L10n.text("Nahrung", table: "ColonyPanelView"), systemImage: "leaf")
                        .font(.subheadline.weight(.semibold))
                    if let storedFood {
                        HStack {
                            Text(L10n.text("Vorrat", table: "ColonyPanelView"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text("\(storedFood)")
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }
                    }
                    if let growthETATurns {
                        Text(growthETATurns == 1
                             ? L10n.text("Wachstum in der nächsten Runde", table: "ColonyPanelView")
                             : L10n.text("Wachstum in etwa \(growthETATurns) Runden", table: "ColonyPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("colony-growth-eta")
                    }
                    productionTableHeader
                    ForEach(foodDisplayItems, id: \.id) { item in
                        productionFlowRow(
                            item,
                            accessibilityIdentifier: "colony-food-source-\(item.id)"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityIdentifier("colony-food-summary")

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 7) {
                    Label(L10n.text("Produktion und Verbrauch", table: "ColonyPanelView"), systemImage: "chart.bar")
                        .font(.subheadline.weight(.semibold))
                    productionTableHeader
                    if nonFoodProductionItems.isEmpty {
                        Text(L10n.text("Keine weitere Produktion oder kein Verbrauch.", table: "ColonyPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(nonFoodProductionItems, id: \.id) { item in
                            productionFlowRow(
                                item,
                                accessibilityIdentifier: "colony-production-\(item.id)"
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityIdentifier("colony-production-summary")
            }
        }
        .accessibilityIdentifier("colony-production-and-food-summary")
    }

    private var storedFood: Int? {
        colony.goods["model.goods.food"] ?? colony.goods["model.goods.grain"]
    }

    private var foodDisplayItems: [ColonyGoodsFlow] {
        let preferredFoodOrder = ["model.goods.grain", "model.goods.fish", "model.goods.food"]
        let orderedFoodIds = preferredFoodOrder.filter(foodGoodsIds.contains)
            + foodGoodsIds
                .filter { !preferredFoodOrder.contains($0) }
                .sorted { GameLabels.name($0) < GameLabels.name($1) }
        return orderedFoodIds.map { goodsId in
            estimatedProduction.first(where: { $0.id == goodsId })
                ?? ColonyGoodsFlow(
                    id: goodsId,
                    label: GameLabels.name(goodsId),
                    produced: 0,
                    consumed: 0,
                    explanation: "\(L10n.text("Produktion:", table: "ColonyPanelView")) +0 \(GameLabels.name(goodsId))\n\(L10n.text("Verbrauch:", table: "ColonyPanelView")) −0 \(GameLabels.name(goodsId))"
                )
        }
    }

    private var nonFoodProductionItems: [ColonyGoodsFlow] {
        estimatedProduction.filter { !foodGoodsIds.contains($0.id) }
    }

    private var productionTableHeader: some View {
        HStack {
            Text(L10n.text("Ware", table: "ColonyPanelView"))
            Spacer(minLength: 4)
            Text(L10n.text("Produktion", table: "ColonyPanelView"))
                .frame(width: 66, alignment: .trailing)
            Text(L10n.text("Verbrauch", table: "ColonyPanelView"))
                .frame(width: 66, alignment: .trailing)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
    }

    private func productionFlowRow(
        _ item: ColonyGoodsFlow,
        accessibilityIdentifier: String
    ) -> some View {
        HStack {
            Text(item.label)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("+\(item.produced)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.green)
                .frame(width: 66, alignment: .trailing)
            Text("\(item.consumed)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.orange)
                .frame(width: 66, alignment: .trailing)
        }
        .help(item.explanation)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text("\(item.label), Produktion \(item.produced), Verbrauch \(item.consumed)", table: "ColonyPanelView"))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var nextBuildQueueCard: some View {
        panelCard(L10n.text("Nächste Bauvorhaben", table: "ColonyPanelView"), systemImage: "hammer") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if canManage && !buildableCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker(L10n.text("Bauvorhaben", table: "ColonyPanelView"), selection: $selectedBuildableId) {
                                ForEach(buildableCandidates, id: \.id) { candidate in
                                    Text(candidate.label).tag(candidate.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)

                            Button {
                                addBuildQueueItem()
                            } label: {
                                Label(L10n.text("Hinzufügen", table: "ColonyPanelView"), systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedBuildableId.isEmpty)
                        }
                    } else if buildableCandidates.isEmpty {
                        Text(L10n.text("Derzeit sind keine weiteren Bauvorhaben verfügbar.", table: "ColonyPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if buildQueueItems.isEmpty {
                        Text(L10n.text("Keine Bauliste festgelegt.", table: "ColonyPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(buildQueueItems.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 4) {
                                    Text(buildingLabel(item))
                                        .font(.callout)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                    Spacer(minLength: 0)
                                    if canManage {
                                        Button {
                                            moveBuildQueueItem(from: index, to: index - 1)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(index == 0)
                                        .help(L10n.text("Bauvorhaben nach oben verschieben", table: "ColonyPanelView"))
                                        .accessibilityLabel(L10n.text("\(buildingLabel(item)) nach oben verschieben", table: "ColonyPanelView"))
                                        .accessibilityIdentifier("build-queue-up-\(index)")

                                        Button {
                                            moveBuildQueueItem(from: index, to: index + 1)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(index == buildQueueItems.count - 1)
                                        .help(L10n.text("Bauvorhaben nach unten verschieben", table: "ColonyPanelView"))
                                        .accessibilityLabel(L10n.text("\(buildingLabel(item)) nach unten verschieben", table: "ColonyPanelView"))
                                        .accessibilityIdentifier("build-queue-down-\(index)")

                                        Button(role: .destructive) {
                                            buildQueueItems.remove(at: index)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help(L10n.text("Bauvorhaben aus der Liste entfernen", table: "ColonyPanelView"))
                                        .accessibilityLabel(L10n.text("\(buildingLabel(item)) entfernen", table: "ColonyPanelView"))
                                        .accessibilityIdentifier("build-queue-remove-\(index)")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            if canManage {
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        applyBuildQueueButton
                        Spacer(minLength: 0)
                        resetBuildQueueButton
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        applyBuildQueueButton
                        HStack {
                            Spacer(minLength: 0)
                            resetBuildQueueButton
                        }
                    }
                }
            }
        }
    }

    private var applyBuildQueueButton: some View {
        Button {
            onSetBuildQueue(buildQueueItems)
        } label: {
            Label(L10n.text("Bauliste übernehmen", table: "ColonyPanelView"), systemImage: "checkmark")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.borderedProminent)
        .fixedSize()
        .accessibilityIdentifier("build-queue-apply")
    }

    private var resetBuildQueueButton: some View {
        Button(L10n.text("Zurücksetzen", table: "ColonyPanelView")) {
            buildQueueItems = currentBuildQueue
        }
        .buttonStyle(.bordered)
        .fixedSize()
        .disabled(buildQueueItems == currentBuildQueue)
    }

    private var visibleGoods: [(id: String, label: String, amount: Int)] {
        guard showAllGoods else { return storedGoods }
        let amounts = Dictionary(uniqueKeysWithValues: storedGoods.map { ($0.id, $0.amount) })
        return goodsCandidates.map { candidate in
            (id: candidate.id, label: candidate.label, amount: amounts[candidate.id] ?? 0)
        }
    }

    private var transferGoodsCandidates: [(id: String, label: String)] {
        goodsCandidates.filter {
            maximumLoadAmount($0.id) > 0 || maximumUnloadAmount($0.id) > 0
        }
    }

    private func metricBadge(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1), in: Capsule())
    }

    private func panelCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(NSColor.controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func statRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }

    private func selectWorkField(_ field: ColonyTerrainField) {
        guard let locationId = field.workLocationId else { return }
        if field.workOptions.count > 1 {
            pendingWorkField = field
        } else {
            // Let `work` assign a sole-output field directly. Passing its
            // inferred type would unnecessarily switch to `rearrangeColony`;
            // an explicit type is only needed after a multi-output choice.
            onWorkAtLocation(locationId, nil)
        }
    }

    func dropWorker(_ workerId: String, in workplace: ColonyBuildingWorkplace) -> Bool {
        guard canManage, units.contains(where: { $0.id == workerId }),
              !workplace.workers.contains(where: { $0.id == workerId }),
              workplace.workers.count < workplace.capacity else { return false }
        onSelectWorker(workerId)
        onWorkAtLocation(workplace.id, workplace.goodsTypeId)
        return true
    }

    func dropWorkerOnField(_ workerId: String, _ field: ColonyTerrainField) -> Bool {
        guard canManage, units.contains(where: { $0.id == workerId }),
              field.unavailableReason == nil, field.workLocationId != nil,
              field.offset != .zero else { return false }
        onSelectWorker(workerId)
        selectWorkField(field)
        return true
    }

    private func validTransferAmount(maximum: Int) -> Bool {
        guard let amount = Int(goodsAmountInput) else { return false }
        return amount > 0 && amount <= maximum
    }

    private func syncWorkerInputs() {
        let worker = units.first { $0.id == selectedWorkerUnitId }
        workTypeId = workTypeCandidates.first(where: { $0.id == worker?.workType })?.id
            ?? workTypeCandidates.first?.id ?? ""
        workImprovementTypeId = workImprovementCandidates.first(where: {
            $0.id == worker?.workImprovementType
        })?.id ?? workImprovementCandidates.first?.id ?? ""
    }

    private func syncGoodsInput() {
        guard !transferGoodsCandidates.contains(where: { $0.id == goodsTypeId }) else { return }
        goodsTypeId = transferGoodsCandidates.first?.id ?? goodsCandidates.first?.id ?? ""
    }

    private func addBuildQueueItem() {
        let trimmed = selectedBuildableId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !buildQueueItems.contains(trimmed) else { return }
        buildQueueItems.append(trimmed)
    }

    private func moveBuildQueueItem(from sourceIndex: Int, to targetIndex: Int) {
        guard buildQueueItems.indices.contains(sourceIndex),
            buildQueueItems.indices.contains(targetIndex)
        else {
            return
        }
        let item = buildQueueItems.remove(at: sourceIndex)
        buildQueueItems.insert(item, at: targetIndex)
    }

}

private struct ColonyFieldProductionChooser: View {
    let field: ColonyTerrainField
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Produktion für dieses Feld", table: "ColonyPanelView"))
                .font(.title2.bold())
            Text(L10n.text("\(field.tile.type.map(GameLabels.name) ?? "Gelände"): Wählen Sie aus, welche Ware der Arbeiter erzeugen soll.", table: "ColonyPanelView"))
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(field.workOptions) { option in
                        Button {
                            onSelect(option.goodsType)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                if let image = TileImageCache.shared.goodsImage(for: option.goodsType) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                } else {
                                    Image(systemName: "shippingbox.fill")
                                        .frame(width: 30, height: 30)
                                }
                                Text(GameLabels.name(option.goodsType))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let amount = option.baseAmount {
                                    Text(L10n.text("Basis \(amount)", table: "ColonyPanelView"))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("colony-production-choice-\(field.id)-\(option.goodsType)")
                    }
                }
            }
            .frame(minHeight: 100, idealHeight: 240, maxHeight: 420)

            HStack {
                Spacer()
                Button(L10n.text("Abbrechen", table: "ColonyPanelView")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 560)
    }
}

/// Custom-house export/import settings for one colony (Java `WarehouseDialog`).
private struct WarehouseSheet: View {
    let exportData: [ColonyExportData]
    let onApply: (ColonyExportData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [String: ColonyExportData] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Lager", table: "ColonyPanelView"))
                .font(.title3.bold())
            Text(L10n.text("Export- und Importgrenzen je Ware.", table: "ColonyPanelView"))
                .font(.caption)
                .foregroundColor(.secondary)

            if exportData.isEmpty {
                Text(L10n.text("Keine Exporteinstellungen vom Server empfangen.", table: "ColonyPanelView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(exportData) { entry in
                            if let binding = draftBinding(for: entry.goodsType) {
                                row(binding)
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }

            HStack {
                Spacer()
                Button(L10n.text("Schließen", table: "ColonyPanelView")) { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 480)
        .onAppear {
            drafts = Dictionary(uniqueKeysWithValues: exportData.map { ($0.goodsType, $0) })
        }
    }

    private func draftBinding(for goodsType: String) -> Binding<ColonyExportData>? {
        guard drafts[goodsType] != nil else { return nil }
        return Binding(
            get: { drafts[goodsType] ?? ColonyExportData(goodsType: goodsType,
                                                         exported: false,
                                                         importLevel: -1,
                                                         exportLevel: 50,
                                                         highLevel: 90,
                                                         lowLevel: 10) },
            set: { drafts[goodsType] = $0 }
        )
    }

    @ViewBuilder
    private func row(_ binding: Binding<ColonyExportData>) -> some View {
        let entry = binding.wrappedValue
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goodsLabel(entry.goodsType))
                    .font(.caption.bold())
                Spacer()
                Toggle(L10n.text("Export", table: "ColonyPanelView"), isOn: binding.exported)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button(L10n.text("Übernehmen", table: "ColonyPanelView")) { onApply(binding.wrappedValue) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: 12) {
                stepper(L10n.text("Import", table: "ColonyPanelView"), value: binding.importLevel, range: -1...999)
                stepper(L10n.text("Export", table: "ColonyPanelView"), value: binding.exportLevel, range: 0...999)
                stepper(L10n.text("Minimum", table: "ColonyPanelView"), value: binding.lowLevel, range: 0...999)
                stepper(L10n.text("Maximum", table: "ColonyPanelView"), value: binding.highLevel, range: 0...999)
            }
        }
    }

    private func stepper(_ title: String,
                         value: Binding<Int>,
                         range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(value.wrappedValue)")
                    .font(.caption)
                    .frame(minWidth: 24, alignment: .trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    private func goodsLabel(_ id: String) -> String {
        GameLabels.name(id)
    }
}
