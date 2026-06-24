//
//  ByTradeView.swift  (Screen 05 — By Trade)
//  Snaglist
//
//  Snags grouped by trade, for handing a clean list to each crew. iOS 14 safe.
//

import SwiftUI

struct ByTradeView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                let groups = store.snagsByTrade()
                if groups.isEmpty {
                    CardView { EmptyStateView(systemImage: "hammer", title: "No snags",
                                              message: "Add snags to see them grouped per trade.") }
                } else {
                    ForEach(groups, id: \.trade) { group in
                        let open = group.snags.filter { $0.isOpen }.count
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9).fill(group.trade.color.opacity(0.16)).frame(width: 34, height: 34)
                                Image(systemName: group.trade.icon).foregroundColor(group.trade.color)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.trade.displayName).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                                Text("\(group.snags.count) snags · \(open) open").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                        ForEach(group.snags) { SnagRow(snag: $0) }
                    }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("By Trade", displayMode: .inline)
    }
}
