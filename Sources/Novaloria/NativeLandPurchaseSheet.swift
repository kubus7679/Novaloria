import SwiftUI
import FreeColGame

struct NativeLandPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tile: FreeColGame.Tile
    let availableGold: Int
    let onPurchase: (String) -> Void

    @State private var offer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Ureinwohnerland kaufen?", table: "InfoPanelView"))
                .font(.headline)
            Text(L10n.text("Feld: \(tile.x), \(tile.y)", table: "InfoPanelView"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.text("Verfügbares Gold: \(availableGold)", table: "InfoPanelView"))
                .font(.caption)
            TextField(L10n.text("Angebot in Goldstücken", table: "InfoPanelView"), text: $offer)
                .textFieldStyle(.roundedBorder)
            Text(L10n.text("Der Server prüft den Mindestpreis. Ein zu niedriges Angebot wird abgelehnt.", table: "InfoPanelView"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L10n.text("Abbrechen", table: "InfoPanelView")) {
                    dismiss()
                }
                Button(L10n.text("Kaufen", table: "InfoPanelView")) {
                    onPurchase(offer)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidOffer)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var isValidOffer: Bool {
        guard let amount = Int(offer.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return amount > 0 && amount <= availableGold
    }
}
