import FreeColGame

struct ColonyEducationProgress: Identifiable {
    let id: String
    let studentUnitTypeId: String
    let remainingTurns: Int
}

/// Display data for one built colony building and its worker slots.
struct ColonyBuildingWorkplace: Identifiable {
    let id: String
    let buildingTypeId: String
    let label: String
    let workers: [FreeColGame.Unit]
    let capacity: Int
    /// The single active (or suggested) goods output for this work location.
    let goodsTypeId: String?
    let productionPerTurn: Int
    let productionExplanation: String
    let isTeachingBuilding: Bool
    let educationProgress: [ColonyEducationProgress]
}
