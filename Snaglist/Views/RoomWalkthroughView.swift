//
//  RoomWalkthroughView.swift  (Screen 01 — Room Walkthrough)
//  Snaglist
//
//  Room-by-room list with each room's open-snag count and readiness %. Buttons:
//  Add Room, Add Snag, Filter (All / Has open / Ready), and Open Room → detail.
//  iOS 14 safe.
//

import SwiftUI

private enum RoomFilter: String, CaseIterable, Identifiable {
    case all, hasOpen, ready
    var id: String { rawValue }
    var title: String {
        switch self { case .all: return "All rooms"; case .hasOpen: return "Has open snags"; case .ready: return "Fully ready" }
    }
}

private enum WalkSheet: Int, Identifiable { case room, snag; var id: Int { rawValue } }

struct RoomWalkthroughView: View {
    @EnvironmentObject var store: AppStore
    @State private var activeSheet: WalkSheet?
    @State private var showFilter = false
    @State private var filter: RoomFilter = .all

    private var rooms: [Room] {
        switch filter {
        case .all: return store.rooms
        case .hasOpen: return store.rooms.filter { store.openCount(in: $0) > 0 }
        case .ready: return store.rooms.filter { store.readiness(of: $0) >= 100 }
        }
    }

    var body: some View {
        ScreenScaffold("Walkthrough", subtitle: store.project.name) {
            // Overall readiness
            CardView {
                HStack(spacing: Theme.Space.m) {
                    ProgressRing(progress: store.handoverReadiness, size: 70, lineWidth: 8, tint: Theme.closed)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Handover readiness").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        Text("\(store.totalOpen) open · \(store.openCriticalCount) critical")
                            .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                        Text("Handover \(Formatters.relativeDays(to: store.project.handoverDate))")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                ActionButton(title: "Add Snag", systemImage: "flag.fill") { activeSheet = .snag }
                ActionButton(title: "Add Room", systemImage: "plus", kind: .secondary) { activeSheet = .room }
            }

            HStack {
                SectionHeader(title: "Rooms", subtitle: filter == .all ? "\(store.rooms.count) total" : filter.title)
                Button(action: { showFilter = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(filter == .all ? "" : ".fill")")
                        .font(.system(size: 20)).foregroundColor(Theme.accent)
                }
            }

            if rooms.isEmpty {
                CardView { EmptyStateView(systemImage: "square.grid.2x2",
                                          title: filter == .all ? "No rooms yet" : "Nothing matches",
                                          message: filter == .all ? "Add the first room to start the walkthrough."
                                                                  : "Try a different filter.") }
            } else {
                ForEach(rooms) { room in RoomCard(room: room) }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .room: RoomEditorSheet(editing: nil).environmentObject(store)
            case .snag: AddSnagView(editingSnag: nil).environmentObject(store)
            }
        }
        .actionSheet(isPresented: $showFilter) {
            ActionSheet(title: Text("Filter rooms"), buttons:
                RoomFilter.allCases.map { f in .default(Text(f.title)) { filter = f } } + [.cancel()])
        }
    }
}

// MARK: - Room card

struct RoomCard: View {
    let room: Room
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationLink(destination: RoomDetailView(roomID: room.id)) {
            HStack(spacing: 14) {
                ProgressRing(progress: store.readiness(of: room), size: 54, lineWidth: 6,
                             tint: store.readiness(of: room) >= 100 ? Theme.closed : Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    HStack(spacing: 6) {
                        let open = store.openCount(in: room)
                        if open > 0 {
                            TagChip(text: "\(open) open", color: Theme.flag, systemImage: "flag.fill")
                        } else {
                            TagChip(text: "No open snags", color: Theme.closed, systemImage: "checkmark")
                        }
                        Text("\(store.snags(in: room).count) total").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
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
}

// MARK: - Room detail

private enum RoomDetailSheet: Int, Identifiable { case addSnag, edit; var id: Int { rawValue } }

struct RoomDetailView: View {
    @EnvironmentObject var store: AppStore
    let roomID: UUID

    @State private var activeSheet: RoomDetailSheet?

    private var room: Room? { store.rooms.first { $0.id == roomID } }

    var body: some View {
        Group {
            if let room = room { content(room) }
            else { EmptyStateView(systemImage: "trash", title: "Room removed", message: "This room no longer exists.") }
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle(room?.name ?? "Room", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { activeSheet = .edit }) {
            Image(systemName: "slider.horizontal.3").foregroundColor(Theme.accent)
        })
    }

    private func content(_ room: Room) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                CardView {
                    HStack(spacing: Theme.Space.m) {
                        ProgressRing(progress: store.readiness(of: room), size: 64, lineWidth: 8,
                                     tint: store.readiness(of: room) >= 100 ? Theme.closed : Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(store.openCount(in: room)) open snags").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Text("\(store.snags(in: room).count) total in this room").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    ActionButton(title: "Add Snag", systemImage: "flag.fill") { activeSheet = .addSnag }
                    NavigationLink(destination: PlanMarkerView(roomID: room.id)) {
                        ActionLabel(title: "Plan Marker", systemImage: "mappin.and.ellipse", kind: .secondary)
                    }.buttonStyle(PlainButtonStyle())
                }

                let snags = store.snags(in: room)
                if snags.isEmpty {
                    CardView { EmptyStateView(systemImage: "checkmark.seal", title: "No snags here",
                                              message: "Tap Add Snag to log a defect in this room.") }
                } else {
                    section("Open", snags.filter { $0.isOpen }, Theme.flag)
                    section("Awaiting verify", snags.filter { $0.status == .fixed }, Theme.review)
                    section("Verified", snags.filter { $0.status == .verified }, Theme.closed)
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addSnag: AddSnagView(editingSnag: nil, presetRoomID: room.id).environmentObject(store)
            case .edit: RoomEditorSheet(editing: room).environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ snags: [Snag], _ tint: Color) -> some View {
        if !snags.isEmpty {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text("\(title) · \(snags.count)").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
            }
            ForEach(snags) { SnagRow(snag: $0, showRoom: false) }
        }
    }
}

// MARK: - Room editor sheet

struct RoomEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let editing: Room?

    @State private var name = ""
    @State private var notes = ""
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Room name", text: $name, placeholder: "e.g. Kitchen")
                    LabeledEditor(label: "Notes", text: $notes, placeholder: "Optional notes for this room…")
                    ActionButton(title: editing == nil ? "Add Room" : "Save", systemImage: "checkmark") { save() }
                    if editing != nil {
                        ActionButton(title: "Delete Room", systemImage: "trash", kind: .danger) { confirmDelete = true }
                        Text("Deleting a room also removes its snags.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(Theme.Space.m)
            }
            .inspectionScreen(showGlyph: false)
            .navigationBarTitle(editing == nil ? "New Room" : "Edit Room", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .actionSheet(isPresented: $confirmDelete) {
            ActionSheet(title: Text("Delete this room?"),
                        message: Text("Its snags will be removed too."),
                        buttons: [.destructive(Text("Delete")) {
                            if let r = editing { store.deleteRoom(r) }
                            presentationMode.wrappedValue.dismiss()
                        }, .cancel()])
        }
        .onAppear {
            guard !loaded else { return }
            if let r = editing { name = r.name; notes = r.notes }
            loaded = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var r = editing {
            r.name = trimmed; r.notes = notes; store.updateRoom(r)
        } else {
            store.addRoom(Room(name: trimmed, notes: notes))
        }
        presentationMode.wrappedValue.dismiss()
    }
}
