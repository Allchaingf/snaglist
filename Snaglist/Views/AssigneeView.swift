//
//  AssigneeView.swift  (Screen 07 — Assignee View)
//  Snaglist
//
//  Who must fix how many, with their next due date. Add/edit assignees; tap a
//  card to see that person's snags. The editor sheet is reused by Add Snag.
//  iOS 14 safe.
//

import SwiftUI

struct AssigneeView: View {
    @EnvironmentObject var store: AppStore
    @State private var showNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                ActionButton(title: "Add Assignee", systemImage: "person.crop.circle.badge.plus") { showNew = true }

                let loads = store.assigneeLoads()
                if loads.isEmpty {
                    CardView { EmptyStateView(systemImage: "person.2", title: "No assignees yet",
                                              message: "Add the people responsible for fixing snags.") }
                } else {
                    ForEach(loads) { load in AssigneeCard(load: load) }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Assignees", displayMode: .inline)
        .sheet(isPresented: $showNew) { AssigneeEditorSheet(editing: nil).environmentObject(store) }
    }
}

struct AssigneeCard: View {
    let load: AppStore.AssigneeLoad
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationLink(destination: AssigneeSnagsView(assigneeID: load.assignee?.id, name: title)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: load.assignee == nil ? "person.fill.questionmark" : load.assignee!.trade.icon)
                        .foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    HStack(spacing: 6) {
                        TagChip(text: "\(load.openCount) to fix", color: load.openCount > 0 ? Theme.flag : Theme.closed,
                                systemImage: load.openCount > 0 ? "flag.fill" : "checkmark")
                        if let due = load.nextDue {
                            TagChip(text: "next \(Formatters.relativeDays(to: due))",
                                    color: due < Date() ? Theme.flag : Theme.textSecondary, systemImage: "calendar")
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var title: String { load.assignee?.name ?? "Unassigned" }
    private var tint: Color { load.assignee?.trade.color ?? Theme.textSecondary }
}

// MARK: - Snags for one assignee

struct AssigneeSnagsView: View {
    @EnvironmentObject var store: AppStore
    let assigneeID: UUID?
    let name: String
    @State private var showEdit = false

    private var snags: [Snag] {
        store.snags.filter { $0.assigneeID == assigneeID }
            .sorted { ($0.isOpen ? 1 : 0, $0.severity.weight) > ($1.isOpen ? 1 : 0, $1.severity.weight) }
    }
    private var assignee: Assignee? { store.assignee(assigneeID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let a = assignee {
                    CardView {
                        HStack(spacing: 12) {
                            Image(systemName: a.trade.icon).foregroundColor(a.trade.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.trade.displayName).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                if !a.contact.isEmpty {
                                    Text(a.contact).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Button(action: { showEdit = true }) {
                                Label("Edit", systemImage: "pencil").font(Theme.caption(12)).foregroundColor(Theme.accent)
                            }
                        }
                    }
                }
                if snags.isEmpty {
                    CardView { EmptyStateView(systemImage: "checkmark.seal", title: "Nothing assigned",
                                              message: "No snags are assigned here.") }
                } else {
                    ForEach(snags) { SnagRow(snag: $0) }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle(name, displayMode: .inline)
        .sheet(isPresented: $showEdit) {
            if let a = assignee { AssigneeEditorSheet(editing: a).environmentObject(store) }
        }
    }
}

// MARK: - Assignee editor sheet (reused by Add Snag)

struct AssigneeEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let editing: Assignee?
    var onSave: ((Assignee) -> Void)? = nil

    @State private var name = ""
    @State private var trade: Trade = .paint
    @State private var contact = ""
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Name", text: $name, placeholder: "e.g. Mia (Painter)")
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TRADE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            Picker("", selection: $trade) {
                                ForEach(Trade.allCases) { Text($0.displayName).tag($0) }
                            }.pickerStyle(MenuPickerStyle()).accentColor(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                        }
                    }
                    LabeledField(label: "Contact", text: $contact, placeholder: "Phone or email (optional)")
                    ActionButton(title: editing == nil ? "Add Assignee" : "Save", systemImage: "checkmark") { save() }
                    if editing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let a = editing { store.deleteAssignee(a) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .inspectionScreen(showGlyph: false)
            .navigationBarTitle(editing == nil ? "New Assignee" : "Edit Assignee", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let a = editing { name = a.name; trade = a.trade; contact = a.contact }
            loaded = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var a = editing ?? Assignee(name: trimmed)
        a.name = trimmed; a.trade = trade; a.contact = contact
        store.saveAssignee(a)
        onSave?(a)
        presentationMode.wrappedValue.dismiss()
    }
}
