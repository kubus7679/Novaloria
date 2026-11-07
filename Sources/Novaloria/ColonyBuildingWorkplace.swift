import FreeColGame

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
    let isTeachingBuilding: Bool
}
