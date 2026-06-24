//
//  VerifyQueueView.swift  (Screen 08 — Verify Queue)
//  Snaglist
//
//  The inspector's queue: snags the contractor marked "fixed", awaiting a
//  re-check. Each row offers Verify (close) or Reopen, both double-confirmed and
//  logged. Sorted criticals-first. iOS 14 safe.
//

import SwiftUI

struct VerifyQueueView: View {
    @EnvironmentObject var store: AppStore
    @State private var verifyTarget: Snag?
    @State private var reopenTarget: Snag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                let queue = store.verifyQueue
                CardView {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.badge.questionmark").font(.system(size: 26)).foregroundColor(Theme.review)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(queue.count) awaiting verification").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Text("Re-check each fix, then verify or reopen.").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                if queue.isEmpty {
                    CardView { EmptyStateView(systemImage: "checkmark.seal.fill", title: "Queue clear",
                                              message: "Nothing is waiting to be verified right now.") }
                } else {
                    ForEach(queue) { snag in verifyRow(snag) }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Verify Queue", displayMode: .inline)
        .alert(item: $verifyTarget) { snag in
            Alert(title: Text("Verify this fix?"),
                  message: Text("\(snag.title) — confirm the defect is properly resolved."),
                  primaryButton: .default(Text("Verify")) { store.verify(snag) },
                  secondaryButton: .cancel())
        }
        .sheet(item: $reopenTarget) { snag in ReopenSheet(snag: snag).environmentObject(store) }
    }

    private func verifyRow(_ snag: Snag) -> some View {
        CardView {
            VStack(spacing: 12) {
                NavigationLink(destination: SnagDetailView(snagID: snag.id)) {
                    HStack(spacing: 12) {
                        thumbnail(snag)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(snag.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary).lineLimit(1)
                            HStack(spacing: 6) {
                                TagChip(text: snag.severity.displayName, color: snag.severity.color, systemImage: snag.severity.icon)
                                TagChip(text: store.roomName(snag.roomID), color: Theme.accent)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textSecondary)
                    }
                }.buttonStyle(PlainButtonStyle())

                HStack(spacing: 10) {
                    ActionButton(title: "Verify", systemImage: "checkmark.seal.fill", kind: .verify) { verifyTarget = snag }
                    ActionButton(title: "Reopen", systemImage: "arrow.uturn.backward", kind: .danger) { reopenTarget = snag }
                }
            }
        }
    }

    private func thumbnail(_ snag: Snag) -> some View {
        ZStack {
            if let img = PhotoStore.shared.loadImage(named: snag.photoFileName) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10).fill(snag.trade.color.opacity(0.16)).frame(width: 48, height: 48)
                    .overlay(Image(systemName: snag.trade.icon).foregroundColor(snag.trade.color))
            }
        }
    }
}
