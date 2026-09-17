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
                Text("Native Trade")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { state.closeNativeTrade() }
            }

            if let session = state.pendingNativeTrade {
                Text("Settlement: \(settlementName(session.settlementId))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Buy from settlement") {
                    itemList(session.settlementToUnit, action: .buy)
                }
                GroupBox("Sell to settlement") {
                    itemList(session.unitToSettlement, action: .sell)
                }
            } else {
                Text("Keine aktive Handels-Session.")
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
            Text("Keine Angebote.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(valid) { item in
                        HStack(spacing: 8) {
                            Text(shortName(item.goodsType, prefix: "model.goods."))
                                .font(.caption)
                            Spacer()
                            Text("x\(item.amount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(item.price) G")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            if item.haggleCount > 0 {
                                Text("haggled \(item.haggleCount)x")
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
            Text("Offer \(offer) G")
                .font(.caption2)
                .frame(width: 78, alignment: .leading)
        }
        .controlSize(.mini)

        Button("Offer") {
            if buying {
                state.nativeTradeBuy(item, offerPrice: offer)
            } else {
                state.nativeTradeSell(item, offerPrice: offer)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button("Accept") {
            if buying {
                state.nativeTradeBuy(item)
            } else {
                state.nativeTradeSell(item)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if !buying {
            Button("Gift") { state.nativeTradeGift(item) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func shortName(_ value: String?, prefix: String) -> String {
        guard let value else { return "?" }
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }
}
