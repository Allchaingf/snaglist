//
//  SnagDetailView.swift  (Screen 03 — Snag Detail)
//  Snaglist
//
//  The defect card and the status flow with double confirmation:
//  Open/Reopened → (contractor) Mark Fixed → (inspector) Verify, or Reopen.
//  Each transition is confirmed and logged to history by the store. iOS 14 safe.
//

import SwiftUI

struct SnagDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let snagID: UUID

    @State private var activeAlert: TransitionAlert?
    @State private var activeSheet: DetailSheet?

    enum TransitionAlert: Int, Identifiable { case fixed, verify, delete; var id: Int { rawValue } }
    enum DetailSheet: Int, Identifiable { case edit, reopen; var id: Int { rawValue } }

    private var snag: Snag? { store.snags.first { $0.id == snagID } }
    private var events: [HistoryEvent] {
        store.history.filter { $0.snagID == snagID }.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        Group {
            if let snag = snag {
                content(snag)
            } else {
                EmptyStateView(systemImage: "trash", title: "Snag removed",
                               message: "This snag no longer exists.")
            }
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Snag", displayMode: .inline)
    }

    private func content(_ snag: Snag) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                statusBanner(snag)
                if snag.photoFileName != nil { photo(snag) }
                detailsCard(snag)
                if !snag.detail.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionHeader(title: "Description", systemImage: "text.alignleft")
                            Text(snag.detail).font(Theme.body()).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                actionButtons(snag)
                historyCard
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit: AddSnagView(editingSnag: snag).environmentObject(store)
            case .reopen: ReopenSheet(snag: snag).environmentObject(store)
            }
        }
        .alert(item: $activeAlert) { alert in transitionAlert(alert, snag: snag) }
    }

    // MARK: - Sections

    private func statusBanner(_ snag: Snag) -> some View {
        CardView {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(snag.status.color.opacity(0.18)).frame(width: 54, height: 54)
                    Image(systemName: snag.status.icon).font(.system(size: 24, weight: .bold))
                        .foregroundColor(snag.status.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(snag.title.isEmpty ? "Untitled snag" : snag.title)
                        .font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                    Text("Status: \(snag.status.displayName)" + (snag.reopenCount > 0 ? " · reopened \(snag.reopenCount)×" : ""))
                        .font(Theme.caption()).foregroundColor(snag.status.color)
                }
                Spacer()
            }
        }
    }

    private func photo(_ snag: Snag) -> some View {
        CardView {
            GeometryReader { geo in
                ZStack {
                    if let img = PhotoStore.shared.loadImage(named: snag.photoFileName) {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: 220).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 30)).foregroundColor(snag.severity.color)
                            .background(Circle().fill(Color.white).frame(width: 13, height: 13))
                            .shadow(radius: 3)
                            .position(x: geo.size.width * CGFloat(snag.marker.x), y: 220 * CGFloat(snag.marker.y))
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private func detailsCard(_ snag: Snag) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                infoRow("Room", store.roomName(snag.roomID), "mappin.and.ellipse", Theme.accent)
                infoRow("Trade", snag.trade.displayName, snag.trade.icon, snag.trade.color)
                infoRow("Severity", snag.severity.displayName, snag.severity.icon, snag.severity.color)
                infoRow("Assignee", store.assigneeName(snag.assigneeID), "person.fill", Theme.accent)
                if let due = snag.dueDate {
                    infoRow("Due", "\(Formatters.date(due)) · \(Formatters.relativeDays(to: due))",
                            "calendar", snag.isOverdue ? Theme.flag : Theme.textSecondary)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(tint).frame(width: 22)
            Text(label).font(Theme.caption()).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(Theme.body()).foregroundColor(Theme.textPrimary).multilineTextAlignment(.trailing)
        }
    }

    private var historyCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Timeline", systemImage: "clock.arrow.circlepath")
                ForEach(events) { e in
                    HStack(spacing: 10) {
                        Image(systemName: e.action.icon).foregroundColor(e.action.color).frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.action.displayName).font(Theme.caption(13)).foregroundColor(Theme.textPrimary)
                            if !e.note.isEmpty {
                                Text(e.note).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(Formatters.dayMonth(e.timestamp)).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    }
                }
                if events.isEmpty {
                    Text("No history yet.").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Status-flow buttons

    private func actionButtons(_ snag: Snag) -> some View {
        VStack(spacing: 10) {
            switch snag.status {
            case .open, .reopened:
                ActionButton(title: "Mark as Fixed", systemImage: "wrench.adjustable.fill", kind: .verify) { activeAlert = .fixed }
                Text("Contractor marks the work done — you verify it next.")
                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            case .fixed:
                ActionButton(title: "Verify Fix", systemImage: "checkmark.seal.fill", kind: .verify) { activeAlert = .verify }
                ActionButton(title: "Reopen", systemImage: "arrow.uturn.backward", kind: .danger) { activeSheet = .reopen }
            case .verified:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(Theme.closed)
                    Text("Verified and closed.").font(Theme.body()).foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.okGlow))
                ActionButton(title: "Reopen", systemImage: "arrow.uturn.backward", kind: .danger) { activeSheet = .reopen }
            }
            HStack(spacing: 10) {
                ActionButton(title: "Edit", systemImage: "pencil", kind: .secondary) { activeSheet = .edit }
                ActionButton(title: "Delete", systemImage: "trash", kind: .danger) { activeAlert = .delete }
            }
        }
    }

    private func transitionAlert(_ alert: TransitionAlert, snag: Snag) -> Alert {
        switch alert {
        case .fixed:
            return Alert(title: Text("Mark as fixed?"),
                         message: Text("This moves the snag to the verify queue for your re-check."),
                         primaryButton: .default(Text("Mark Fixed")) { store.markFixed(snag) },
                         secondaryButton: .cancel())
        case .verify:
            return Alert(title: Text("Verify this fix?"),
                         message: Text("Confirm the defect is properly resolved. This closes the snag."),
                         primaryButton: .default(Text("Verify")) { store.verify(snag) },
                         secondaryButton: .cancel())
        case .delete:
            return Alert(title: Text("Delete snag?"),
                         message: Text("This permanently removes the snag and its photo."),
                         primaryButton: .destructive(Text("Delete")) {
                             store.deleteSnag(snag); presentationMode.wrappedValue.dismiss()
                         },
                         secondaryButton: .cancel())
        }
    }
}

// MARK: - Reopen sheet (captures an optional reason)

struct ReopenSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let snag: Snag
    @State private var note = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(Theme.flag)
                            Text("Reopening sends this snag back to the contractor as still open.")
                                .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                    }
                    LabeledEditor(label: "Reason (optional)", text: $note, placeholder: "e.g. Fix did not hold on re-check")
                    ActionButton(title: "Reopen Snag", systemImage: "arrow.uturn.backward", kind: .danger) {
                        store.reopen(snag, note: note.trimmingCharacters(in: .whitespaces))
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(Theme.Space.m)
            }
            .inspectionScreen(showGlyph: false)
            .navigationBarTitle("Reopen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") { presentationMode.wrappedValue.dismiss() }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
