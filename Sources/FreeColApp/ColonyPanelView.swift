import SwiftUI
import FreeColGame

struct ColonyPanelView: View {
    let colony: Colony
    let ownerName: String
    let units: [FreeColGame.Unit]
    let canManage: Bool
    let selectedWorkerUnitId: String?
    let onChangeWorkType: (String) -> Void
    let onChangeWorkImprovementType: (String) -> Void
    let onClearSpeciality: () -> Void
    let onAssignTeacher: (String) -> Void
    let onClearTeacher: () -> Void
    let onWorkAtLocation: (String) -> Void
    let onRenameColony: (String) -> Void
    let onPayForBuilding: () -> Void
    let onSetGoodsLevels: () -> Void
    let onAbandonColony: () -> Void
    let canAbandonColony: Bool
    let onRearrangeColony: () -> Void
    let onSetBuildQueue: ([String]) -> Void
    let onPutOutsideColony: () -> Void
    let canPutOutsideColony: Bool
    let selectedCarrierId: String?
    let onLoadGoods: (String, Int) -> Void
    let onUnloadGoods: (String, Int) -> Void

    @State private var workTypeId: String = "model.goods.grain"
    @State private var workImprovementTypeId: String = "model.improvement.plow"
    @State private var teacherId: String = ""
    @State private var workLocationId: String = ""
    @State private var colonyNameInput: String
    @State private var buildQueueDraft: String = ""
    @State private var buildQueueItems: [String] = []
    @State private var goodsTypeId: String = "model.goods.grain"
    @State private var goodsAmountInput: String = "10"
    @State private var showAbandonConfirmation: Bool = false

    init(
        colony: Colony,
        ownerName: String,
        units: [FreeColGame.Unit],
        canManage: Bool,
        selectedWorkerUnitId: String?,
        onChangeWorkType: @escaping (String) -> Void,
        onChangeWorkImprovementType: @escaping (String) -> Void,
        onClearSpeciality: @escaping () -> Void,
        onAssignTeacher: @escaping (String) -> Void,
        onClearTeacher: @escaping () -> Void,
        onWorkAtLocation: @escaping (String) -> Void,
        onRenameColony: @escaping (String) -> Void,
        onPayForBuilding: @escaping () -> Void,
        onSetGoodsLevels: @escaping () -> Void,
        onAbandonColony: @escaping () -> Void,
        canAbandonColony: Bool,
        onRearrangeColony: @escaping () -> Void,
        onSetBuildQueue: @escaping ([String]) -> Void,
        onPutOutsideColony: @escaping () -> Void,
        canPutOutsideColony: Bool,
        selectedCarrierId: String?,
        onLoadGoods: @escaping (String, Int) -> Void,
        onUnloadGoods: @escaping (String, Int) -> Void
    ) {
        self.colony = colony
        self.ownerName = ownerName
        self.units = units
        self.canManage = canManage
        self.selectedWorkerUnitId = selectedWorkerUnitId
        self.onChangeWorkType = onChangeWorkType
        self.onChangeWorkImprovementType = onChangeWorkImprovementType
        self.onClearSpeciality = onClearSpeciality
        self.onAssignTeacher = onAssignTeacher
        self.onClearTeacher = onClearTeacher
        self.onWorkAtLocation = onWorkAtLocation
        self.onRenameColony = onRenameColony
        self.onPayForBuilding = onPayForBuilding
        self.onSetGoodsLevels = onSetGoodsLevels
        self.onAbandonColony = onAbandonColony
        self.canAbandonColony = canAbandonColony
        self.onRearrangeColony = onRearrangeColony
        self.onSetBuildQueue = onSetBuildQueue
        self.onPutOutsideColony = onPutOutsideColony
        self.canPutOutsideColony = canPutOutsideColony
        self.selectedCarrierId = selectedCarrierId
        self.onLoadGoods = onLoadGoods
        self.onUnloadGoods = onUnloadGoods
        _colonyNameInput = State(initialValue: colony.name ?? "")
    }

    var body: some View {
        GroupBox("Colony") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(colony.name ?? colony.id)
                        .font(.headline)
                    Spacer()
                    Text("\(colony.sonsOfLiberty)% SoL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        Text("Owner")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ownerName)
                            .font(.caption)
                    }
                    GridRow {
                        Text("Population")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(max(colony.unitCount, units.count))")
                            .font(.caption)
                    }
                    GridRow {
                        Text("Liberty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(colony.liberty)")
                            .font(.caption)
                    }
                    GridRow {
                        Text("Immigration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(colony.immigration)")
                            .font(.caption)
                    }
                }

                Divider()

                Text("Production")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        Text("Established")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.established)")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Population")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.unitCount)")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Production Bonus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.productionBonus)%")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Liberty / Immigration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.liberty) / \(colony.immigration)")
                            .font(.caption2)
                    }
                }

                Divider()

                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if units.isEmpty {
                    Text("No visible units in colony")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(units, id: \.id) { unit in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(unit.unitType ?? unit.id)
                                        .font(.caption)
                                    if selectedWorkerUnitId == unit.id {
                                        Text("Selected")
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
                                Text(unit.state.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(unit.movesLeft) MP")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                Text("Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Colony Name", text: $colonyNameInput)
                    .textFieldStyle(.roundedBorder)
                Button("Rename Colony") {
                    onRenameColony(colonyNameInput)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || colonyNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || colonyNameInput.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(colony.name ?? "") == .orderedSame)

                Button("Pay For Building") {
                    onPayForBuilding()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Button("Set Goods Levels") {
                    onSetGoodsLevels()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Button("Abandon Colony") {
                    showAbandonConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || !canAbandonColony)

                Text("Worker: \(selectedWorkerUnitId ?? "none")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextField("WorkType ID", text: $workTypeId)
                    .textFieldStyle(.roundedBorder)
                Button("Change Work Type") {
                    onChangeWorkType(workTypeId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                TextField("Work Improvement Type ID", text: $workImprovementTypeId)
                    .textFieldStyle(.roundedBorder)
                Button("Change Work Improvement Type") {
                    onChangeWorkImprovementType(workImprovementTypeId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Button("Clear Speciality") {
                    onClearSpeciality()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                TextField("Teacher ID", text: $teacherId)
                    .textFieldStyle(.roundedBorder)
                Button("Assign Teacher") {
                    onAssignTeacher(teacherId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Button("Clear Teacher") {
                    onClearTeacher()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                if let selectedWorkerUnitId,
                   let selectedWorker = units.first(where: { $0.id == selectedWorkerUnitId }) {
                    Divider()
                    Text("Selected Worker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedWorker.unitType ?? selectedWorker.id)
                        .font(.caption)
                    Text(unitWorkLabel(selectedWorker))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Teacher: \(selectedWorker.teacher ?? "none")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                TextField("Work Location ID", text: $workLocationId)
                    .textFieldStyle(.roundedBorder)
                Button("Work At Location") {
                    onWorkAtLocation(workLocationId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Button("Rearrange Colony") {
                    onRearrangeColony()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Text("Build Queue")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Add buildable ID", text: $buildQueueDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Add") {
                        addBuildQueueItem()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManage || buildQueueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear") {
                        buildQueueItems.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManage || buildQueueItems.isEmpty)
                }

                if buildQueueItems.isEmpty {
                    Text("No build queue set.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(buildQueueItems.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text(item)
                                    .font(.caption2)
                                Spacer()
                                Button("Up") {
                                    moveBuildQueueItem(from: index, to: index - 1)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || index == 0)

                                Button("Down") {
                                    moveBuildQueueItem(from: index, to: index + 1)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || index == buildQueueItems.count - 1)

                                Button("Remove") {
                                    buildQueueItems.remove(at: index)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage)
                            }
                        }
                    }
                }

                Button("Set Build Queue") {
                    onSetBuildQueue(buildQueueItems)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Button("Put Outside Colony") {
                    onPutOutsideColony()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || !canPutOutsideColony)

                Divider()

                Text("Goods")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Carrier: \(selectedCarrierId ?? "none")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextField("Goods Type ID", text: $goodsTypeId)
                    .textFieldStyle(.roundedBorder)
                TextField("Amount", text: $goodsAmountInput)
                    .textFieldStyle(.roundedBorder)

                Button("Load Goods") {
                    let amount = Int(goodsAmountInput) ?? 0
                    onLoadGoods(goodsTypeId, amount)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedCarrierId == nil)

                Button("Unload Goods") {
                    let amount = Int(goodsAmountInput) ?? 0
                    onUnloadGoods(goodsTypeId, amount)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedCarrierId == nil)
            }
            .padding(.vertical, 4)
        }
        .confirmationDialog(
            "Abandon this colony?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon Colony", role: .destructive) {
                onAbandonColony()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the colony and cannot be undone.")
        }
    }

    private func addBuildQueueItem() {
        let trimmed = buildQueueDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        buildQueueItems.append(trimmed)
        buildQueueDraft = ""
    }

    private func moveBuildQueueItem(from sourceIndex: Int, to targetIndex: Int) {
        guard buildQueueItems.indices.contains(sourceIndex),
              buildQueueItems.indices.contains(targetIndex) else {
            return
        }
        let item = buildQueueItems.remove(at: sourceIndex)
        buildQueueItems.insert(item, at: targetIndex)
    }

    private func unitWorkLabel(_ unit: FreeColGame.Unit) -> String {
        var parts: [String] = []
        if let workType = unit.workType, !workType.isEmpty {
            parts.append("Work: \(workType)")
        }
        if let workImprovement = unit.workImprovementType, !workImprovement.isEmpty {
            parts.append("Improvement: \(workImprovement)")
        }
        if let teacher = unit.teacher, !teacher.isEmpty {
            parts.append("Teacher: \(teacher)")
        }
        if parts.isEmpty {
            return "No work assignment"
        }
        return parts.joined(separator: " | ")
    }
}
