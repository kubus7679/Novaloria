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
    let carrierGoods: [(id: String, label: String, amount: Int)]
    let buildTargetLabel: String?
    let buildRequirements: [(id: String, label: String, required: Int, stored: Int)]
    let buildPaymentCost: Int?
    let buildETATurns: Int?
    let estimatedBuildPerTurn: Int
    let estimatedProduction: [ColonyGoodsFlow]
    let growthETATurns: Int?
    let foodGoodsIds: Set<String>

    @State private var workTypeId: String = "model.goods.grain"
    @State private var workImprovementTypeId: String = ""
    @State private var teacherId: String = ""
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
    @State private var section: ColonySection = .overview

    enum ColonySection: String, CaseIterable {
        case overview = "Übersicht"
        case workers = "Arbeiter und Felder"
        case production = "Produktion und Bau"
        case storage = "Lager und Fracht"
    }

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
        carrierGoods: [(id: String, label: String, amount: Int)] = [],
        buildTargetLabel: String? = nil,
        buildRequirements: [(id: String, label: String, required: Int, stored: Int)] = [],
        buildPaymentCost: Int? = nil,
        buildETATurns: Int? = nil,
        estimatedBuildPerTurn: Int = 0,
        estimatedProduction: [ColonyGoodsFlow] = [],
        growthETATurns: Int? = nil,
        foodGoodsIds: Set<String> = ["model.goods.food", "model.goods.grain", "model.goods.fish"],
        section: ColonySection = .overview
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
        self.carrierGoods = carrierGoods
        self.buildTargetLabel = buildTargetLabel
        self.buildRequirements = buildRequirements
        self.buildPaymentCost = buildPaymentCost
        self.buildETATurns = buildETATurns
        self.estimatedBuildPerTurn = estimatedBuildPerTurn
        self.estimatedProduction = estimatedProduction
        self.growthETATurns = growthETATurns
        self.foodGoodsIds = foodGoodsIds
        _colonyNameInput = State(initialValue: colony.name ?? "")
        _buildQueueItems = State(initialValue: currentBuildQueue)
        _selectedBuildableId = State(initialValue: buildableCandidates.first?.id ?? "")
        _workTypeId = State(initialValue: workTypeCandidates.first?.id ?? "")
        _goodsTypeId = State(initialValue: (goodsCandidates ?? workTypeCandidates).first?.id ?? "")
        _section = State(initialValue: section)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                metricBadge("Bevölkerung", value: "\(population)", systemImage: "person.2")
                Spacer(minLength: 0)
            }
            Picker("Bereich", selection: $section) {
                ForEach(ColonySection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("colony-section")
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if section == .overview {
                        panelCard("Status", systemImage: "building.2") {
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                                statRow("Besitzer", value: ownerName)
                                statRow("Freiheitsstreben", value: "\(colony.sonsOfLiberty)%")
                                statRow("Freiheit", value: "\(colony.liberty)")
                                statRow("Einwanderung", value: "\(colony.immigration)")
                                statRow("Gegründet", value: "\(colony.established)")
                                statRow("Produktionsbonus", value: "\(colony.productionBonus)%")
                            }
                        }
                    }

                    if section == .workers {
                        VStack(alignment: .leading, spacing: 10) {
                            unassignedWorkersRow
                            terrainCard
                            buildingWorkplacesCard
                            selectedWorkerActions
                        }
                    }

                    if section == .overview {
                        DisclosureGroup("Verwaltung") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("Koloniename", text: $colonyNameInput)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityIdentifier("colony-name")
                                        .onSubmit {
                                            if canRename { onRenameColony(colonyNameInput) }
                                        }
                                    Button("Umbenennen") {
                                        onRenameColony(colonyNameInput)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("colony-rename")
                                    .disabled(!canRename)
                                }
                                if canManage && canAbandonColony {
                                    Button("Kolonie verlassen…", role: .destructive) {
                                        showAbandonConfirmation = true
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("colony-abandon")
                                }
                            }
                            .padding(.top, 6)
                        }
                    }

                    if section == .production {
                        if buildTargetLabel != nil {
                            HStack(alignment: .top, spacing: 10) {
                                currentBuildCard
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                nextBuildQueueCard
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        } else {
                            nextBuildQueueCard
                        }
                        if hasProductionSummary {
                            colonyProductionSummaryCard
                        }
                    }

                    if section == .storage {
                        panelCard("Lagerbestand", systemImage: "shippingbox") {
                            if goodsCandidates.count > storedGoods.count {
                                Toggle("Auch Waren mit Bestand 0 anzeigen", isOn: $showAllGoods)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                            }
                            if visibleGoods.isEmpty {
                                Text("Keine gelagerten Waren.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
                                          alignment: .leading, spacing: 6) {
                                    ForEach(visibleGoods, id: \.id) { item in
                                        LabeledContent(item.label, value: "\(item.amount)")
                                            .font(.callout)
                                    }
                                }
                            }
                        }

                        if canManage && !exportData.isEmpty {
                            Button("Export- und Importregeln…") { showWarehouse = true }
                                .buttonStyle(.bordered)
                        }

                        if let selectedCarrierId {
                            panelCard("Fracht", systemImage: "shippingbox.fill") {
                                if carrierCandidates.count > 1 {
                                    Picker("Frachter", selection: Binding(
                                        get: { selectedCarrierId },
                                        set: onSelectCarrier
                                    )) {
                                        ForEach(carrierCandidates, id: \.id) { carrier in
                                            Text(carrier.label).tag(carrier.id)
                                        }
                                    }
                                    .accessibilityIdentifier("colony-carrier-picker")
                                }
                                if let selectedCarrierDescription {
                                    Text(selectedCarrierDescription)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                if carrierGoods.isEmpty {
                                    Text("Der Transporter ist leer.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(carrierGoods, id: \.id) { item in
                                        LabeledContent(item.label, value: "\(item.amount)")
                                            .font(.callout)
                                    }
                                }

                                if !transferGoodsCandidates.isEmpty {
                                    Picker("Ware", selection: $goodsTypeId) {
                                        ForEach(transferGoodsCandidates, id: \.id) { candidate in
                                            Text(candidate.label).tag(candidate.id)
                                        }
                                    }
                                    TextField("Menge", text: $goodsAmountInput)
                                        .textFieldStyle(.roundedBorder)

                                    let loadMaximum = maximumLoadAmount(goodsTypeId)
                                    let unloadMaximum = maximumUnloadAmount(goodsTypeId)
                                    HStack(spacing: 8) {
                                        if loadMaximum > 0 {
                                            Button("Max laden: \(loadMaximum)") {
                                                goodsAmountInput = String(loadMaximum)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        if unloadMaximum > 0 {
                                            Button("Max entladen: \(unloadMaximum)") {
                                                goodsAmountInput = String(unloadMaximum)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        if loadMaximum > 0 {
                                            Button("Laden") {
                                                onLoadGoods(goodsTypeId, Int(goodsAmountInput) ?? 0)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(!canManage || !validTransferAmount(maximum: loadMaximum))
                                        }
                                        if unloadMaximum > 0 {
                                            Button("Entladen") {
                                                onUnloadGoods(goodsTypeId, Int(goodsAmountInput) ?? 0)
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(!canManage || !validTransferAmount(maximum: unloadMaximum))
                                        }
                                    }
                                }
                            }
                            .accessibilityIdentifier("colony-carrier-\(selectedCarrierId)")
                        } else {
                            Text("Frachtaktionen werden angezeigt, wenn ein Transporter ausgewählt ist.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(minHeight: 300, idealHeight: 480, maxHeight: 760)
        .background(Color(NSColor.windowBackgroundColor))
        .confirmationDialog(
            "Diese Kolonie verlassen?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Kolonie verlassen", role: .destructive) {
                onAbandonColony()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Kolonie wird unwiderruflich entfernt.")
        }
        .alert(
            "Bau bezahlen?",
            isPresented: $showBuildPaymentConfirmation
        ) {
            Button("Ja") {
                onPayForBuilding()
            }
            Button("Nein", role: .cancel) {}
        } message: {
            if let buildPaymentCost {
                Text("Möchtest du \(buildPaymentCost.formatted(.number.locale(Locale(identifier: "de_DE")))) Gold bezahlen, um den Bau abzuschließen?")
            } else {
                Text("Der zu zahlende Goldbetrag konnte nicht ermittelt werden. Möchtest du den Bau trotzdem bezahlen?")
            }
        }
        .sheet(isPresented: $showWarehouse) {
            WarehouseSheet(exportData: exportData, onApply: onSetGoodsLevel)
        }
        .onAppear {
            syncWorkerInputs()
            syncGoodsInput()
        }
        .onChange(of: selectedWorkerUnitId) { _, _ in syncWorkerInputs() }
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
            || teacherCandidates.contains { $0.id != selectedWorker.id }
            || selectedWorker.teacher != nil
            || (selectedWorker.role != nil && selectedWorker.role != "model.role.default")
            || canPutOutsideColony
    }

    private var terrainCard: some View {
        panelCard("Koloniegelände", systemImage: "map") {
            if terrainFields.isEmpty {
                Text("Keine Felder verfügbar.")
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
                    showsHeader: false
                )
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
                    Text("Ohne sichtbaren Arbeitsplatz")
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
                Text(worker.unitType.map(GameLabels.name) ?? "Arbeiter")
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
        .help("\(worker.unitType.map(GameLabels.name) ?? "Arbeiter") auswählen")
        .accessibilityIdentifier("colony-unassigned-worker-\(worker.id)")
    }

    @ViewBuilder
    private var selectedWorkerActions: some View {
        if let selectedWorker, hasSelectedWorkerActions {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if workTypeCandidates.count > 1 {
                        HStack(spacing: 8) {
                            Picker("Produktion", selection: $workTypeId) {
                                ForEach(workTypeCandidates, id: \.id) { candidate in
                                    Text(candidate.label).tag(candidate.id)
                                }
                            }
                            .disabled(!canManage)
                            Button("Ändern") { onChangeWorkType(workTypeId) }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || !workTypeCandidates.contains { $0.id == workTypeId })
                        }
                    }

                    if !workImprovementCandidates.isEmpty {
                        HStack(spacing: 8) {
                            Picker("Verbesserung", selection: $workImprovementTypeId) {
                                ForEach(workImprovementCandidates, id: \.id) { candidate in
                                    Text(candidate.label).tag(candidate.id)
                                }
                            }
                            .disabled(!canManage)
                            Button("Ändern") {
                                onChangeWorkImprovementType(workImprovementTypeId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canManage || !workImprovementCandidates.contains {
                                $0.id == workImprovementTypeId
                            })
                        }
                    }

                    let otherWorkers = teacherCandidates.filter { $0.id != selectedWorker.id }
                    let studentIsWorking = colony.buildings.contains {
                        $0.id == selectedWorker.location
                    } || colony.workTiles.contains {
                        $0.id == selectedWorker.location
                    }
                    if !otherWorkers.isEmpty {
                        HStack(spacing: 8) {
                            Picker("Lehrer", selection: $teacherId) {
                                ForEach(otherWorkers, id: \.id) { candidate in
                                    Text(candidate.unitType.map(GameLabels.name) ?? "Einheit")
                                        .tag(candidate.id)
                                }
                            }
                            .disabled(!canManage)
                            Button("Zuweisen") { onAssignTeacher(teacherId) }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || teacherId.isEmpty || !studentIsWorking)
                        }
                        if !studentIsWorking {
                            Text("Der Schüler muss zuerst in einem Gebäude oder auf einem Feld arbeiten.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if selectedWorker.teacher != nil {
                        Button("Lehrer entfernen", action: onClearTeacher)
                            .buttonStyle(.bordered)
                            .disabled(!canManage)
                    }
                    if selectedWorker.role != nil && selectedWorker.role != "model.role.default" {
                        Button("Spezialisierung löschen", action: onClearSpeciality)
                            .buttonStyle(.bordered)
                            .disabled(!canManage)
                    }
                    if canPutOutsideColony {
                        Button("Vor die Kolonie stellen", action: onPutOutsideColony)
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 6)
            } label: {
                Label("Weitere Aktionen", systemImage: "ellipsis.circle")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 3)
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

        return panelCard("Gebäude", systemImage: "building.2") {
            if buildingWorkplaces.isEmpty {
                if buildings.isEmpty {
                    Text("In dieser Kolonie gibt es noch keine Gebäude.")
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
                    Text("\(occupied) von \(capacity) Arbeitsplätzen belegt")
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250), alignment: .top)],
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
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "building.2.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workplace.label)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("\(workplace.workers.count)/\(workplace.capacity) Arbeiter")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 40, alignment: .leading)

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
                        Text(GameLabels.name(goodsTypeId))
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("+\(workplace.productionPerTurn) / Runde")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(workplace.productionPerTurn > 0 ? .green : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(GameLabels.name(goodsTypeId)), \(workplace.productionPerTurn) pro Runde"
                    )
                } else if workplace.isTeachingBuilding {
                    Label("Ausbildung", systemImage: "graduationcap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine aktive Produktion")
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
                                Text(worker.unitType.map(GameLabels.name) ?? "Arbeiter")
                                    .font(.caption2)
                                    .lineLimit(1)
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
                        .help("\(worker.unitType.map(GameLabels.name) ?? "Arbeiter") auswählen")
                        .accessibilityIdentifier("colony-building-worker-\(worker.id)")
                    }

                    if workplace.workers.count < workplace.capacity {
                        let freeSlots = workplace.capacity - workplace.workers.count
                        Button {
                            onWorkAtLocation(workplace.id, workplace.goodsTypeId)
                        } label: {
                            Label("Zuweisen", systemImage: "plus")
                                .font(.caption)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canAssign)
                        .help(canAssign
                            ? "Ausgewählten Arbeiter diesem Gebäude zuweisen"
                            : "Wählen Sie einen geeigneten Arbeiter aus; freie Plätze: \(freeSlots)")
                        .accessibilityIdentifier("colony-building-assign-\(workplace.id)")
                    } else if workplace.capacity == 0 {
                        Text("Keine Arbeiterplätze")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 40, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 158, alignment: .topLeading)
        .background(
            Color(NSColor.controlBackgroundColor).opacity(0.48),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityIdentifier("colony-building-\(workplace.id)")
    }

    private var currentBuildCard: some View {
        panelCard(
            buildTargetLabel == nil ? "Produktion" : "Aktueller Bauauftrag",
            systemImage: "hammer"
        ) {
            Text("Vorhersage mit aktiven Aufträgen, Boni und Vorräten.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                        ProgressView(
                            value: requirement.required > 0
                                ? min(1.0, Double(requirement.stored) / Double(requirement.required))
                                : 1.0
                        )
                    }
                }
                HStack {
                    Text("Bauhämmer pro Runde")
                    Spacer(minLength: 4)
                    Text(estimatedBuildPerTurn > 0 ? "\(estimatedBuildPerTurn)" : "—")
                        .monospacedDigit()
                }
                .font(.caption)
                if let eta = buildETATurns {
                    Text(eta == 0 ? "Fertig in der nächsten Runde" : "Noch etwa \(eta) Runden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if canManage {
                    Button("Bau bezahlen") {
                        showBuildPaymentConfirmation = true
                    }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("colony-pay-for-building")
                }
            }

        }
    }

    private var hasProductionSummary: Bool {
        !estimatedProduction.isEmpty || growthETATurns != nil || storedFood != nil
    }

    private var colonyProductionSummaryCard: some View {
        panelCard("Nahrung und Produktion", systemImage: "chart.bar") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Nahrung", systemImage: "leaf")
                        .font(.subheadline.weight(.semibold))
                    if let storedFood {
                        HStack {
                            Text("Vorrat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text("\(storedFood)")
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }
                    }
                    if let growthETATurns {
                        Text(growthETATurns == 1
                             ? "Wachstum in der nächsten Runde"
                             : "Wachstum in etwa \(growthETATurns) Runden")
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
                    Label("Produktion und Verbrauch", systemImage: "chart.bar")
                        .font(.subheadline.weight(.semibold))
                    productionTableHeader
                    if nonFoodProductionItems.isEmpty {
                        Text("Keine weitere Produktion oder kein Verbrauch.")
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
                    explanation: "Produktion: +0 \(GameLabels.name(goodsId))\nVerbrauch: −0 \(GameLabels.name(goodsId))"
                )
        }
    }

    private var nonFoodProductionItems: [ColonyGoodsFlow] {
        estimatedProduction.filter { !foodGoodsIds.contains($0.id) }
    }

    private var productionTableHeader: some View {
        HStack {
            Text("Ware")
            Spacer(minLength: 4)
            Text("Produktion")
                .frame(width: 66, alignment: .trailing)
            Text("Verbrauch")
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
        .accessibilityLabel("\(item.label), Produktion \(item.produced), Verbrauch \(item.consumed)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var nextBuildQueueCard: some View {
        panelCard("Nächste Bauvorhaben", systemImage: "hammer") {
            if canManage && !buildableCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Bauvorhaben", selection: $selectedBuildableId) {
                        ForEach(buildableCandidates, id: \.id) { candidate in
                            Text(candidate.label).tag(candidate.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Button {
                        addBuildQueueItem()
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedBuildableId.isEmpty)
                }
            } else if buildableCandidates.isEmpty {
                Text("Derzeit sind keine weiteren Bauvorhaben verfügbar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if buildQueueItems.isEmpty {
                Text("Keine Bauliste festgelegt.")
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
                                .help("Bauvorhaben nach oben verschieben")
                                .accessibilityLabel("\(buildingLabel(item)) nach oben verschieben")
                                .accessibilityIdentifier("build-queue-up-\(index)")

                                Button {
                                    moveBuildQueueItem(from: index, to: index + 1)
                                } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(index == buildQueueItems.count - 1)
                                .help("Bauvorhaben nach unten verschieben")
                                .accessibilityLabel("\(buildingLabel(item)) nach unten verschieben")
                                .accessibilityIdentifier("build-queue-down-\(index)")

                                Button(role: .destructive) {
                                    buildQueueItems.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Bauvorhaben aus der Liste entfernen")
                                .accessibilityLabel("\(buildingLabel(item)) entfernen")
                                .accessibilityIdentifier("build-queue-remove-\(index)")
                            }
                        }
                    }
                }
            }

            if canManage {
                HStack(spacing: 8) {
                    Button("Bauliste übernehmen") { onSetBuildQueue(buildQueueItems) }
                        .buttonStyle(.borderedProminent)
                    Button("Zurücksetzen") { buildQueueItems = currentBuildQueue }
                        .buttonStyle(.bordered)
                        .disabled(buildQueueItems == currentBuildQueue)
                }
            }
        }
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

    private func validTransferAmount(maximum: Int) -> Bool {
        guard let amount = Int(goodsAmountInput) else { return false }
        return amount > 0 && amount <= maximum
    }

    private func syncWorkerInputs() {
        let worker = units.first { $0.id == selectedWorkerUnitId }
        workTypeId = workTypeCandidates.first(where: { $0.id == worker?.workType })?.id
            ?? workTypeCandidates.first?.id ?? ""
        teacherId = worker?.teacher ?? ""
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
            Text("Produktion für dieses Feld")
                .font(.title2.bold())
            Text("\(field.tile.type.map(GameLabels.name) ?? "Gelände"): Wählen Sie aus, welche Ware der Arbeiter erzeugen soll.")
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
                                    Text("Basis \(amount)")
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
                Button("Abbrechen") { dismiss() }
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
            Text("Lager")
                .font(.title3.bold())
            Text("Export- und Importgrenzen je Ware.")
                .font(.caption)
                .foregroundColor(.secondary)

            if exportData.isEmpty {
                Text("Keine Exporteinstellungen vom Server empfangen.")
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
                Button("Schließen") { dismiss() }
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
                Toggle("Export", isOn: binding.exported)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Übernehmen") { onApply(binding.wrappedValue) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: 12) {
                stepper("Import", value: binding.importLevel, range: -1...999)
                stepper("Export", value: binding.exportLevel, range: 0...999)
                stepper("Minimum", value: binding.lowLevel, range: 0...999)
                stepper("Maximum", value: binding.highLevel, range: 0...999)
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
