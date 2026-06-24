//
//  AddSnagView.swift  (Screen 02 — Add Snag)
//  Snaglist
//
//  The snag editor, presented as a sheet for both Add and Edit. Captures room,
//  trade, severity, photo + a draggable pin marker, description, assignee and
//  due date. Every control is bound to a draft and persisted on Save. iOS 14 safe.
//

import SwiftUI

private enum SnagSheet: Int, Identifiable { case camera, library, newAssignee; var id: Int { rawValue } }

struct AddSnagView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    /// nil = create new. Non-nil = edit existing.
    let editingSnag: Snag?
    /// Pre-selected room when adding from a room context.
    var presetRoomID: UUID? = nil

    @State private var draft: Snag = Snag()
    @State private var hasDueDate = false
    @State private var originalPhoto: String? = nil
    @State private var showSource = false
    @State private var activeSheet: SnagSheet?
    @State private var titleError = false
    @State private var loaded = false

    private var isEditing: Bool { editingSnag != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Title", text: $draft.title, placeholder: "e.g. Cracked tile above sink")
                    if titleError {
                        Text("A title is required.").font(Theme.caption(11)).foregroundColor(Theme.flag)
                    }

                    photoCard

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            // Room
                            menuPicker(title: "ROOM") {
                                Picker("", selection: $draft.roomID) {
                                    Text("Unassigned").tag(UUID?.none)
                                    ForEach(store.rooms) { Text($0.name).tag(Optional($0.id)) }
                                }.pickerStyle(MenuPickerStyle()).accentColor(Theme.accent)
                            }
                            // Trade
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TRADE / CATEGORY").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                tradePicker
                            }
                            // Severity
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SEVERITY").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                Picker("", selection: $draft.severity) {
                                    ForEach(Severity.allCases) { Text($0.displayName).tag($0) }
                                }.pickerStyle(SegmentedPickerStyle())
                            }
                        }
                    }

                    LabeledEditor(label: "Description", text: $draft.detail, placeholder: "Describe the defect…")

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            // Assignee
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("ASSIGNEE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Button(action: { activeSheet = .newAssignee }) {
                                        Label("New", systemImage: "plus").font(Theme.caption(11)).foregroundColor(Theme.accent)
                                    }
                                }
                                Picker("", selection: $draft.assigneeID) {
                                    Text("Unassigned").tag(UUID?.none)
                                    ForEach(store.assignees) { Text($0.name).tag(Optional($0.id)) }
                                }.pickerStyle(MenuPickerStyle()).accentColor(Theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                            }
                            // Due date
                            Toggle(isOn: $hasDueDate.animation()) {
                                Text("Set fix deadline").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                            if hasDueDate {
                                DatePicker("Due", selection: Binding(
                                    get: { draft.dueDate ?? store.project.handoverDate },
                                    set: { draft.dueDate = $0 }), displayedComponents: .date)
                                    .accentColor(Theme.accent).font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }
                        }
                    }

                    ActionButton(title: isEditing ? "Save Changes" : "Add Snag", systemImage: "checkmark") { save() }
                    if isEditing {
                        ActionButton(title: "Delete Snag", systemImage: "trash", kind: .danger) {
                            if let s = editingSnag { store.deleteSnag(s) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .inspectionScreen(showGlyph: false)
            .navigationBarTitle(isEditing ? "Edit Snag" : "New Snag", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { cancel() }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .actionSheet(isPresented: $showSource) {
            ActionSheet(title: Text("Add defect photo"), buttons: [
                .default(Text("Take Photo")) { activeSheet = .camera },
                .default(Text("Choose from Library")) { activeSheet = .library },
                .cancel()
            ])
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera: CameraPicker { handlePhoto($0) }
            case .library: PhotoLibraryPicker { handlePhoto($0) }
            case .newAssignee:
                AssigneeEditorSheet(editing: nil) { created in draft.assigneeID = created.id }
                    .environmentObject(store)
            }
        }
        .onAppear(perform: configure)
    }

    // MARK: - Photo + pin

    private var photoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Photo & marker", systemImage: "camera.viewfinder")
                    Spacer()
                    Button(action: { showSource = true }) {
                        Label(draft.photoFileName == nil ? "Add" : "Replace", systemImage: "camera.fill")
                            .font(Theme.caption(12)).foregroundColor(Theme.accent)
                    }
                }
                if let img = PhotoStore.shared.loadImage(named: draft.photoFileName) {
                    GeometryReader { geo in
                        ZStack {
                            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: 200).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32)).foregroundColor(draft.severity.color)
                                .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                                .shadow(radius: 3)
                                .position(x: geo.size.width * CGFloat(draft.marker.x),
                                          y: 200 * CGFloat(draft.marker.y))
                                .gesture(DragGesture().onChanged { v in
                                    draft.marker.x = Double(min(max(v.location.x / geo.size.width, 0), 1))
                                    draft.marker.y = Double(min(max(v.location.y / 200, 0), 1))
                                })
                        }
                    }
                    .frame(height: 200)
                    Text("Drag the pin to the exact defect spot.")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                } else {
                    Button(action: { showSource = true }) {
                        RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt)
                            .frame(height: 120)
                            .overlay(VStack(spacing: 6) {
                                Image(systemName: "camera.fill").font(.system(size: 26)).foregroundColor(Theme.accent)
                                Text("Add a defect photo").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                            })
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var tradePicker: some View {
        // Show enabled trades + the current one if it happens to be disabled.
        let trades = Trade.allCases.filter { store.project.enabledTrades.contains($0) || $0 == draft.trade }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(trades) { trade in
                    let on = draft.trade == trade
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { draft.trade = trade } }) {
                        HStack(spacing: 5) {
                            Image(systemName: trade.icon).font(.system(size: 12, weight: .bold))
                            Text(trade.displayName).font(Theme.caption(12))
                        }
                        .foregroundColor(on ? .white : trade.color)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(on ? trade.color : trade.color.opacity(0.14)))
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func menuPicker<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
        }
    }

    // MARK: - Actions

    private func configure() {
        guard !loaded else { return }
        if let s = editingSnag {
            draft = s
            hasDueDate = s.dueDate != nil
            originalPhoto = s.photoFileName
        } else {
            var s = Snag()
            s.roomID = presetRoomID ?? store.rooms.first?.id
            s.trade = store.project.enabledTrades.first ?? .paint
            draft = s
        }
        loaded = true
    }

    private func handlePhoto(_ image: UIImage) {
        // Save immediately; if a previous *new* photo was set, drop it.
        if draft.photoFileName != originalPhoto { PhotoStore.shared.delete(named: draft.photoFileName) }
        if let name = PhotoStore.shared.save(image) { draft.photoFileName = name }
    }

    private func save() {
        let trimmed = draft.title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { titleError = true }; return }
        draft.title = trimmed
        if !hasDueDate { draft.dueDate = nil }
        store.saveSnag(draft)
        presentationMode.wrappedValue.dismiss()
    }

    private func cancel() {
        // Clean up a freshly-attached photo that won't be saved.
        if draft.photoFileName != originalPhoto { PhotoStore.shared.delete(named: draft.photoFileName) }
        presentationMode.wrappedValue.dismiss()
    }
}
