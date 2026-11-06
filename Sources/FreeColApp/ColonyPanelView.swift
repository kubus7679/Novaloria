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
    let workTypeCandidates: [(id: String, label: String)]
    let goodsCandidates: [(id: String, label: String)]
    let workImprovementCandidates: [(id: String, label: String)]
    let onAbandonColony: () -> Void
    let canAbandonColony: Bool
    let onSetBuildQueue: ([String]) -> Void
    let onPutOutsideColony: () -> Void
    let canPutOutsideColony: Bool
    let selectedCarrierId: String?
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
    let buildETATurns: Int?
    let estimatedBuildPerTurn: Int
    let estimatedProduction: [(id: String, label: String, amount: Int)]

    @State private var workTypeId: String = "model.goods.grain"
    @State private var workImprovementTypeId: String = ""
    @State private var teacherId: String = ""
    @State private var workLocationId: String = ""
    @State private var colonyNameInput: String
    @State private var buildQueueItems: [String] = []
    @State private var selectedBuildableId: String = ""
    @State private var goodsTypeId: String = "model.goods.grain"
    @State private var goodsAmountInput: String = "10"
    @State private var showAbandonConfirmation: Bool = false
    @State private var showWarehouse: Bool = false
    @State private var showAllGoods: Bool = false
    @State private var pendingWorkField: ColonyTerrainField?
    @State private var showFieldProductionChooser: Bool = false
    @State private var section: ColonySection = .overview

    enum ColonySection: String, CaseIterable {
        case overview = "Übersicht"
        case workers = "Arbeiter und Felder"
        case production = "Gebäude und Bau"
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
        workTypeCandidates: [(id: String, label: String)] = [],
        goodsCandidates: [(id: String, label: String)]? = nil,
        workImprovementCandidates: [(id: String, label: String)] = [],
        onAbandonColony: @escaping () -> Void,
        canAbandonColony: Bool,
        onSetBuildQueue: @escaping ([String]) -> Void,
        onPutOutsideColony: @escaping () -> Void,
        canPutOutsideColony: Bool,
        selectedCarrierId: String?,
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
        buildETATurns: Int? = nil,
        estimatedBuildPerTurn: Int = 0,
        estimatedProduction: [(id: String, label: String, amount: Int)] = [],
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
        self.workTypeCandidates = workTypeCandidates
        self.goodsCandidates = goodsCandidates ?? workTypeCandidates
        self.workImprovementCandidates = workImprovementCandidates
        self.onAbandonColony = onAbandonColony
        self.canAbandonColony = canAbandonColony
        self.onSetBuildQueue = onSetBuildQueue
        self.onPutOutsideColony = onPutOutsideColony
        self.canPutOutsideColony = canPutOutsideColony
        self.selectedCarrierId = selectedCarrierId
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
        self.buildETATurns = buildETATurns
        self.estimatedBuildPerTurn = estimatedBuildPerTurn
        self.estimatedProduction = estimatedProduction
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
                if let food = colony.goods["model.goods.food"] ?? colony.goods["model.goods.grain"] {
                    metricBadge("Nahrung", value: "\(food)", systemImage: "leaf")
                }
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
                            terrainCard
                            workerListCard
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
                        if buildTargetLabel != nil || !estimatedProduction.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                currentBuildCard
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                nextBuildQueueCard
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        } else {
                            nextBuildQueueCard
                        }

                        if !buildings.isEmpty {
                            panelCard("Gebäude", systemImage: "building.2") {
                                ForEach(buildings, id: \.id) { building in
                                    Label(building.label, systemImage: "building.2.crop.circle")
                                        .font(.callout)
                                }
                            }
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
                    if section == .workers {
                        if let selectedWorker = selectedWorker {
                            panelCard("Arbeiteraktionen", systemImage: "person.crop.circle") {
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

                                if !buildingWorkLocationCandidates.isEmpty {
                                    HStack(spacing: 8) {
                                        Picker("Gebäude", selection: $workLocationId) {
                                            ForEach(buildingWorkLocationCandidates, id: \.id) { candidate in
                                                Text(candidate.label).tag(candidate.id)
                                            }
                                        }
                                        .disabled(!canManage)
                                        Button("Zuweisen") { onWorkAtLocation(workLocationId, nil) }
                                            .buttonStyle(.bordered)
                                            .disabled(!canManage || workLocationId.isEmpty)
                                    }
                                    Text("Im Gebäude beginnt der Arbeiter automatisch mit der dortigen Produktion.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
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

                                let otherWorkers = units.filter { $0.id != selectedWorker.id }
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
                                            .disabled(!canManage || teacherId.isEmpty)
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
                        } else if canManage && !units.isEmpty {
                            ContentUnavailableView(
                                "Kein Arbeiter ausgewählt",
                                systemImage: "person.crop.circle",
                                description: Text("Wählen Sie einen Arbeiter aus der Liste aus.")
                            )
                        } else if !canManage && !units.isEmpty {
                            Text("Arbeiterverwaltung ist derzeit nicht verfügbar.")
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
        .confirmationDialog(
            "Produktion für dieses Feld",
            isPresented: $showFieldProductionChooser,
            titleVisibility: .visible
        ) {
            if let field = pendingWorkField, let locationId = field.workLocationId {
                ForEach(field.workOptions) { option in
                    Button(option.label) {
                        onWorkAtLocation(locationId, option.goodsType)
                        pendingWorkField = nil
                    }
                }
            }
            Button("Abbrechen", role: .cancel) { pendingWorkField = nil }
        } message: {
            Text("Wählen Sie aus, welche Ware der Arbeiter auf diesem Feld erzeugen soll.")
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
        .onChange(of: buildingWorkLocationCandidates.map(\.id)) { _, _ in syncWorkerInputs() }
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
                    onSelectField: selectWorkField,
                    showsHeader: false
                )
            }
        }
    }

    private var workerListCard: some View {
        panelCard("Arbeiter", systemImage: "person.2") {
            if units.isEmpty {
                Text("Keine Arbeiter in dieser Kolonie.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 5) {
                    ForEach(units, id: \.id) { unit in
                        Button {
                            onSelectWorker(unit.id)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(unit.unitType.map(GameLabels.name) ?? "Einheit")
                                        .font(.subheadline.weight(.medium))
                                    Text(unitWorkLabel(unit))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(workerLocationLabel(unit))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 4)
                                if selectedWorkerUnitId == unit.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                        .accessibilityLabel("Ausgewählt")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                selectedWorkerUnitId == unit.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canManage)
                        .accessibilityIdentifier("colony-worker-\(unit.id)")
                    }
                }
            }
        }
    }

    private var buildingWorkLocationCandidates: [(id: String, label: String)] {
        let buildingIds = Set(colony.buildings.map(\.id))
        return workLocationCandidates.filter { buildingIds.contains($0.id) }
    }

    private var currentBuildCard: some View {
        panelCard(
            buildTargetLabel == nil ? "Produktion" : "Aktueller Bauauftrag",
            systemImage: "hammer"
        ) {
            Text("Basiswerte ohne Boni oder Warenverbrauch.")
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
                    Text("Bauhämmer pro Runde (Basis)")
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
                    Button("Bau bezahlen", action: onPayForBuilding)
                        .buttonStyle(.borderedProminent)
                }
            }

            if !estimatedProduction.isEmpty {
                if buildTargetLabel != nil { Divider() }
                Text("Produktion pro Runde (Basis)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(estimatedProduction, id: \.id) { item in
                    HStack {
                        Text(item.label)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.amount >= 0 ? "+\(item.amount)" : "\(item.amount)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(item.amount >= 0 ? .green : .red)
                    }
                }
            }
        }
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
            showFieldProductionChooser = true
        } else {
            onWorkAtLocation(locationId, field.workOptions.first?.goodsType)
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
        workLocationId = buildingWorkLocationCandidates.first(where: { $0.id == worker?.location })?.id
            ?? buildingWorkLocationCandidates.first?.id ?? ""
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

    private func unitWorkLabel(_ unit: FreeColGame.Unit) -> String {
        var parts: [String] = []
        if let workType = unit.workType, !workType.isEmpty {
            parts.append("Produktion: \(GameLabels.name(workType))")
        }
        if let workImprovement = unit.workImprovementType, !workImprovement.isEmpty {
            parts.append("Verbesserung: \(GameLabels.name(workImprovement))")
        }
        if let teacher = unit.teacher, !teacher.isEmpty {
            let teacherName = units.first(where: { $0.id == teacher })?.unitType.map(GameLabels.name) ?? "Zugewiesen"
            parts.append("Lehrer: \(teacherName)")
        }
        if parts.isEmpty {
            return "Kein Arbeitsauftrag"
        }
        return parts.joined(separator: " | ")
    }

    private func workerLocationLabel(_ unit: FreeColGame.Unit) -> String {
        guard let location = unit.location else { return "Arbeitsplatz unbekannt" }
        if location == colony.id || colony.tileId == location { return "Koloniezentrum" }
        if let candidate = workLocationCandidates.first(where: { $0.id == location }) {
            return "Arbeitsplatz: \(candidate.label)"
        }
        return "Arbeitsplatz nicht verfügbar"
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
