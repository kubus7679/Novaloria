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
    let onWorkAtLocation: (String) -> Void
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
    let buildableCandidates: [(id: String, label: String)]
    let buildings: [(id: String, label: String)]
    let currentBuildQueue: [String]
    let buildingLabel: (String) -> String
    let storedGoods: [(id: String, label: String, amount: Int)]
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
        onWorkAtLocation: @escaping (String) -> Void,
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
        buildableCandidates: [(id: String, label: String)] = [],
        buildings: [(id: String, label: String)] = [],
        currentBuildQueue: [String] = [],
        buildingLabel: @escaping (String) -> String = { $0 },
        storedGoods: [(id: String, label: String, amount: Int)] = [],
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
        self.buildableCandidates = buildableCandidates
        self.buildings = buildings
        self.currentBuildQueue = currentBuildQueue
        self.buildingLabel = buildingLabel
        self.storedGoods = storedGoods
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Bevölkerung: \(population)", systemImage: "person.2")
                Text("Nahrung: \(colony.goods["model.goods.food"] ?? colony.goods["model.goods.grain"] ?? 0)")
                Spacer()
            }
            .font(.caption)
            Text("Bauauftrag: \(buildTargetLabel ?? "Keiner")")
                .font(.caption)
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
                        HStack {
                            Text(colony.name ?? colony.id)
                                .font(.headline)
                            Spacer()
                            Text("\(colony.sonsOfLiberty)% Freiheitsstreben")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                            GridRow {
                                Text("Besitzer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ownerName)
                                    .font(.caption)
                            }
                            GridRow {
                                Text("Freiheit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(colony.liberty)")
                                    .font(.caption)
                            }
                            GridRow {
                                Text("Einwanderung")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(colony.immigration)")
                                    .font(.caption)
                            }
                        }

                        Divider()

                        Text("Produktion")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                            GridRow {
                                Text("Gegründet")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(colony.established)")
                                    .font(.caption2)
                            }
                            GridRow {
                                Text("Produktionsbonus")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(colony.productionBonus)%")
                                    .font(.caption2)
                            }
                            GridRow {
                                Text("Freiheit / Einwanderung")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(colony.liberty) / \(colony.immigration)")
                                    .font(.caption2)
                            }
                        }

                        Divider()
                    }

                    if section == .workers {
                        Picker("Arbeiter", selection: Binding(
                            get: { selectedWorkerUnitId ?? "" },
                            set: { onSelectWorker($0) }
                        )) {
                            if units.isEmpty { Text("Keine Arbeiter").tag("") }
                            ForEach(units, id: \.id) { unit in
                                Text("\(unit.unitType.map(GameLabels.name) ?? "Einheit") · \(unitWorkLabel(unit))")
                                    .tag(unit.id)
                            }
                        }
                        .disabled(!canManage || units.isEmpty)
                        ColonyTerrainView(fields: terrainFields, selectedWorkerId: selectedWorkerUnitId,
                                          canManage: canManage, onAssign: onWorkAtLocation)
                        Divider()
                        Text("Arbeiter")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if units.isEmpty {
                            Text("Keine sichtbaren Arbeiter in der Kolonie.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(units, id: \.id) { unit in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Button(unit.unitType.map(GameLabels.name) ?? "Einheit") {
                                                onSelectWorker(unit.id)
                                            }
                                            .font(.caption)
                                            if selectedWorkerUnitId == unit.id {
                                                Text("Ausgewählt")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text(unitWorkLabel(unit))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(GameLabels.state(unit.state))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(unit.movesLeft) Bewegungspunkte")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        Divider()
                    }

                    if section == .overview {
                        Text("Verwaltung")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Koloniename", text: $colonyNameInput)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("colony-name")
                            .onSubmit {
                                if canRename { onRenameColony(colonyNameInput) }
                            }
                        Button("Kolonie umbenennen") {
                            onRenameColony(colonyNameInput)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("colony-rename")
                        .disabled(!canRename)
                        Button("Kolonie verlassen…", role: .destructive) {
                            showAbandonConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("colony-abandon")
                        .disabled(!canManage || !canAbandonColony)
                    }

                    if section == .production {
                        Button("Bau bezahlen") {
                            onPayForBuilding()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage)
                    }

                    if section == .storage {
                        Button("Export und Import…") {
                            showWarehouse = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage)
                        ForEach(storedGoods, id: \.id) { item in
                            LabeledContent(item.label, value: "\(item.amount)")
                        }
                        if storedGoods.isEmpty {
                            Text("Keine gelagerten Waren.").foregroundStyle(.secondary)
                        }
                    }
                    if section == .workers {
                        Text(
                            "Arbeiter: \(units.first(where: { $0.id == selectedWorkerUnitId })?.unitType.map(GameLabels.name) ?? "Keiner")"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)

                        Picker("Produktion", selection: $workTypeId) {
                            ForEach(workTypeCandidates, id: \.id) { candidate in
                                Text(GameLabels.name(candidate.id)).tag(candidate.id)
                            }
                        }
                        .disabled(!canManage || selectedWorkerUnitId == nil)
                        Button("Produktion ändern") {
                            onChangeWorkType(workTypeId)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedWorkerUnitId == nil
                                  || !workTypeCandidates.contains(where: { $0.id == workTypeId }))

                        if !workImprovementCandidates.isEmpty {
                            Picker("Verbesserung", selection: $workImprovementTypeId) {
                                ForEach(workImprovementCandidates, id: \.id) { candidate in
                                    Text(GameLabels.name(candidate.id)).tag(candidate.id)
                                }
                            }
                            .disabled(!canManage || selectedWorkerUnitId == nil)
                            Button("Verbesserung ändern") {
                                onChangeWorkImprovementType(workImprovementTypeId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canManage || selectedWorkerUnitId == nil
                                      || !workImprovementCandidates.contains(where: { $0.id == workImprovementTypeId }))
                        }

                        Button("Spezialisierung löschen") {
                            onClearSpeciality()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedWorkerUnitId == nil)

                        Picker("Lehrer", selection: $teacherId) {
                            Text("Keiner").tag("")
                            ForEach(units.filter { $0.id != selectedWorkerUnitId }, id: \.id) { candidate in
                                Text(candidate.unitType.map(GameLabels.name) ?? "Einheit").tag(candidate.id)
                            }
                        }
                        .disabled(!canManage || selectedWorkerUnitId == nil)
                        Button("Lehrer zuweisen") {
                            onAssignTeacher(teacherId)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedWorkerUnitId == nil || teacherId.isEmpty)

                        Button("Lehrer entfernen") {
                            onClearTeacher()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedWorkerUnitId == nil)

                        if let selectedWorkerUnitId,
                            let selectedWorker = units.first(where: { $0.id == selectedWorkerUnitId })
                        {
                            Divider()
                            Text("Ausgewählter Arbeiter")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedWorker.unitType.map(GameLabels.name) ?? "Einheit")
                                .font(.caption)
                            Text(unitWorkLabel(selectedWorker))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(
                                "Lehrer: \(selectedWorker.teacher.flatMap { id in units.first(where: { $0.id == id })?.unitType }.map(GameLabels.name) ?? "Keiner")"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }

                        if workLocationCandidates.isEmpty {
                            Text("Keine Arbeitsplaetze verfügbar.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Arbeitsplatz", selection: $workLocationId) {
                                ForEach(workLocationCandidates, id: \.id) { candidate in
                                    Text(candidate.label).tag(candidate.id)
                                }
                            }
                            .disabled(!canManage || selectedWorkerUnitId == nil)
                            Button("Arbeiter zuweisen") {
                                onWorkAtLocation(workLocationId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canManage || selectedWorkerUnitId == nil || workLocationId.isEmpty)
                        }
                    }

                    if section == .production {
                        if buildTargetLabel != nil || !storedGoods.isEmpty {
                            Divider()

                            Text("Produktionsschätzung")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let target = buildTargetLabel {
                                Text("Bauauftrag: \(target)")
                                    .font(.caption2)
                                ForEach(buildRequirements, id: \.id) { requirement in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(requirement.label)
                                                .font(.caption2)
                                            Spacer()
                                            Text("\(requirement.stored)/\(requirement.required)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        ProgressView(
                                            value: requirement.required > 0
                                                ? min(1.0, Double(requirement.stored) / Double(requirement.required))
                                                : 1.0
                                        )
                                        .frame(width: 180)
                                    }
                                }
                                HStack {
                                    Text("Geschätzte Produktion")
                                        .font(.caption2)
                                    Spacer()
                                    Text(estimatedBuildPerTurn > 0 ? "\(estimatedBuildPerTurn)/Runde" : "—")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let eta = buildETATurns {
                                    Text(eta == 0 ? "Nächste Runde fertig" : "Noch etwa \(eta) Runden")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if !estimatedProduction.isEmpty {
                                Text("Pro Runde (geschätzt)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                ForEach(estimatedProduction, id: \.id) { item in
                                    HStack {
                                        Text(item.label)
                                            .font(.caption2)
                                        Spacer()
                                        Text(item.amount >= 0 ? "+\(item.amount)" : "\(item.amount)")
                                            .font(.caption2)
                                            .foregroundColor(item.amount >= 0 ? .green : .red)
                                    }
                                }
                            }
                        }

                        Text("Gebäude")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if buildings.isEmpty {
                            Text("Keine Gebäude gemeldet.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(buildings, id: \.id) { building in
                                Text(building.label)
                                    .font(.caption2)
                            }
                        }

                        Text("Bauliste")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if buildableCandidates.isEmpty {
                            Text("Keine Bauoptionen verfügbar.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            HStack {
                                Picker("Bauvorhaben", selection: $selectedBuildableId) {
                                    ForEach(buildableCandidates, id: \.id) { candidate in
                                        Text(candidate.label).tag(candidate.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 220)

                                Button("Hinzufügen") {
                                    addBuildQueueItem()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || selectedBuildableId.isEmpty)
                            }
                        }

                        if buildQueueItems.isEmpty {
                            Text("Keine Bauliste festgelegt.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(buildQueueItems.enumerated()), id: \.offset) { index, item in
                                    HStack {
                                        Text(buildingLabel(item))
                                            .font(.caption2)
                                        Spacer()
                                        Button("Hoch") {
                                            moveBuildQueueItem(from: index, to: index - 1)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!canManage || index == 0)

                                        Button("Runter") {
                                            moveBuildQueueItem(from: index, to: index + 1)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!canManage || index == buildQueueItems.count - 1)

                                        Button("Entfernen") {
                                            buildQueueItems.remove(at: index)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!canManage)
                                    }
                                }
                            }
                        }

                        HStack {
                            Button("Bauliste übernehmen") {
                                onSetBuildQueue(buildQueueItems)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canManage)

                            Button("Zurücksetzen") {
                                buildQueueItems = currentBuildQueue
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canManage || buildQueueItems == currentBuildQueue)
                        }
                    }

                    if section == .workers {
                        Button("Vor die Kolonie stellen") {
                            onPutOutsideColony()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || !canPutOutsideColony)
                    }

                    if section == .storage {
                        Divider()

                        Text("Fracht")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(selectedCarrierId == nil ? "Kein Transporter ausgewählt." : "Transporter ausgewählt")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Picker("Ware", selection: $goodsTypeId) {
                            ForEach(goodsCandidates, id: \.id) { candidate in
                                Text(GameLabels.name(candidate.id)).tag(candidate.id)
                            }
                        }
                        TextField("Menge", text: $goodsAmountInput)
                            .textFieldStyle(.roundedBorder)

                        Button("Waren laden") {
                            let amount = Int(goodsAmountInput) ?? 0
                            onLoadGoods(goodsTypeId, amount)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedCarrierId == nil
                                  || !goodsCandidates.contains(where: { $0.id == goodsTypeId })
                                  || (Int(goodsAmountInput) ?? 0) <= 0)

                        Button("Waren entladen") {
                            let amount = Int(goodsAmountInput) ?? 0
                            onUnloadGoods(goodsTypeId, amount)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedCarrierId == nil
                                  || !goodsCandidates.contains(where: { $0.id == goodsTypeId })
                                  || (Int(goodsAmountInput) ?? 0) <= 0)
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
        .sheet(isPresented: $showWarehouse) {
            WarehouseSheet(exportData: exportData, onApply: onSetGoodsLevel)
        }
        .onAppear {
            syncWorkerInputs()
            if !workImprovementCandidates.contains(where: { $0.id == workImprovementTypeId }) {
                workImprovementTypeId = workImprovementCandidates.first?.id ?? ""
            }
        }
        .onChange(of: selectedWorkerUnitId) { _, _ in syncWorkerInputs() }
        .onChange(of: workTypeCandidates.map(\.id)) { _, _ in syncWorkerInputs() }
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

    private func syncWorkerInputs() {
        let worker = units.first { $0.id == selectedWorkerUnitId }
        workTypeId = workTypeCandidates.first(where: { $0.id == worker?.workType })?.id
            ?? workTypeCandidates.first?.id ?? ""
        workLocationId = workLocationCandidates.first(where: { $0.id == worker?.location })?.id
            ?? workLocationCandidates.first?.id ?? ""
        teacherId = worker?.teacher ?? ""
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
