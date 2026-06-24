//
//  HistoryView.swift  (Screen 12 — History)
//  Snaglist
//
//  An immutable, reverse-chronological audit log of every status change
//  (created / fixed / verified / reopened …) with filter chips. iOS 14 safe.
//

import SwiftUI

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, created, fixed, verified, reopened
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    func matches(_ a: HistoryAction) -> Bool {
        switch self {
        case .all: return true
        case .created: return a == .created
        case .fixed: return a == .markedFixed
        case .verified: return a == .verified
        case .reopened: return a == .reopened
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter: HistoryFilter = .all

    private var events: [HistoryEvent] { store.history.filter { filter.matches($0.action) } }

    var body: some View {
        ScreenScaffold("History", subtitle: "Every status change, newest first") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoryFilter.allCases) { f in
                        let on = filter == f
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filter = f } }) {
                            Text(f.title)
                                .font(Theme.caption(12))
                                .foregroundColor(on ? .white : Theme.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(on ? Theme.accent : Theme.surface))
                                .overlay(Capsule().stroke(Theme.stroke, lineWidth: on ? 0 : 1))
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }

            if events.isEmpty {
                CardView { EmptyStateView(systemImage: "clock.arrow.circlepath", title: "No history",
                                          message: "Status changes will appear here as you work through snags.") }
            } else {
                CardView {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(e.action.color.opacity(0.16)).frame(width: 34, height: 34)
                                    Image(systemName: e.action.icon).font(.system(size: 14, weight: .bold)).foregroundColor(e.action.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(e.action.displayName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                        if let from = e.fromStatus, let to = e.toStatus {
                                            Text("\(from.displayName) → \(to.displayName)")
                                                .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    Text(e.snagTitle).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                    if !e.note.isEmpty {
                                        Text("“\(e.note)”").font(Theme.caption(11)).foregroundColor(Theme.textSecondary).italic()
                                    }
                                    Text(Formatters.dateTime(e.timestamp)).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            if idx < events.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }
}
