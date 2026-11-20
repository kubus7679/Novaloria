import FreeColGame

enum NativeAlarmDisplay {
    static func label(for value: Int) -> String {
        switch NativeAlarmLevel(value: value) {
        case .happy: return L10n.text("HAPPY", table: "NativeSettlementPanelView")
        case .content: return L10n.text("CONTENT", table: "NativeSettlementPanelView")
        case .displeased: return L10n.text("DISPLEASED", table: "NativeSettlementPanelView")
        case .angry: return L10n.text("ANGRY", table: "NativeSettlementPanelView")
        case .hateful: return L10n.text("HATEFUL", table: "NativeSettlementPanelView")
        }
    }
}
