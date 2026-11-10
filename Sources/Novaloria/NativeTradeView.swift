import SwiftUI
import FreeColGame

/// Interactive native trade session (buy/sell/gift goods) modelled on the Java
/// client's native trade dialog.
struct NativeTradeView: View {
    @Environment(GameState.self) private var state

    @State private var offerPrices: [String: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Handel mit Ureinwohnern", table: "NativeTradeView"))
                    .font(.title2.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "NativeTradeView")) { state.closeNativeTrade() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(state.isNativeInteractionInProgress)
            }

            if let session = state.pendingNativeTrade {
                Text(L10n.text("Siedlung: \(settlementName(session.settlementId))", table: "NativeTradeView"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox(L10n.text("Von der Siedlung kaufen", table: "NativeTradeView")) {
                    itemList(session.settlementToUnit, action: .buy)
                }
                GroupBox(L10n.text("An die Siedlung verkaufen", table: "NativeTradeView")) {
                    itemList(session.unitToSettlement, action: .sell)
                }
            } else {
                Text(L10n.text("Kein aktiver Handel.", table: "NativeTradeView"))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: state.pendingNativeTrade?.item?.price) { _, _ in
            // A server haggle/counter-offer produces new prices: drop stale offers.
            offerPrices.removeAll()
        }
    }

    private func settlementName(_ settlementId: String?) -> String {
        guard let settlementId else { return "?" }
        return state.game?.colonies[settlementId]?.name ?? settlementId
    }

    private enum TradeAction {
        case buy
        case sell
    }

    @ViewBuilder
    private func itemList(_ items: [NativeTradeItem], action: TradeAction) -> some View {
        let valid = items.filter { $0.priceIsValid }
        if valid.isEmpty {
            Text(L10n.text("Keine Angebote.", table: "NativeTradeView"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(valid) { item in
                        HStack(spacing: 8) {
                            Text(item.goodsType.map(state.goodsDisplayName) ?? L10n.text("Ware", table: "NativeTradeView"))
                                .font(.caption)
                            Spacer()
                            Text(L10n.text("x\(item.amount)", table: "NativeTradeView"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(L10n.text("\(item.price) G", table: "NativeTradeView"))
                                .font(.caption)
                                .foregroundColor(.yellow)
                            if item.haggleCount > 0 {
                                Text(L10n.text("Nachverhandelt: \(item.haggleCount)×", table: "NativeTradeView"))
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }

                            offerControls(item: item, action: action)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 160)
        }
    }

    @ViewBuilder
    private func offerControls(item: NativeTradeItem, action: TradeAction) -> some View {
        let buying = action == .buy
        let offer = offerPrices[item.id] ?? state.nativeTradeHaggleOffer(item, buying: buying)

        Stepper(value: Binding(
            get: { offerPrices[item.id] ?? state.nativeTradeHaggleOffer(item, buying: buying) },
            set: { offerPrices[item.id] = max(1, $0) }
        ), in: 1...(max(2, item.price) * 3)) {
            Text(L10n.text("Angebot: \(offer) G", table: "NativeTradeView"))
                .font(.caption2)
                .frame(width: 78, alignment: .leading)
        }
        .controlSize(.mini)
        .disabled(state.isNativeInteractionInProgress)

        Button(L10n.text("Anbieten", table: "NativeTradeView")) {
            if buying {
                state.nativeTradeBuy(item, offerPrice: offer)
            } else {
                state.nativeTradeSell(item, offerPrice: offer)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(state.isNativeInteractionInProgress)

        Button(L10n.text("Annehmen", table: "NativeTradeView")) {
            if buying {
                state.nativeTradeBuy(item)
            } else {
                state.nativeTradeSell(item)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(state.isNativeInteractionInProgress)

        if !buying {
            Button(L10n.text("Schenken", table: "NativeTradeView")) { state.nativeTradeGift(item) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.isNativeInteractionInProgress)
        }
    }

}
