//
//  PlanMarkerView.swift  (Screen 04 — Plan Marker)
//  Snaglist
//
//  A room photo / plan with one draggable pin per snag, colored by severity.
//  Drag a pin to reposition (committed on release); tap a pin to open the snag.
//  iOS 14 safe (PHPicker + PhotoStore, programmatic NavigationLink).
//

import SwiftUI

private enum PlanPicker: Int, Identifiable { case camera, library; var id: Int { rawValue } }

struct PlanMarkerView: View {
    @EnvironmentObject var store: AppStore
    let roomID: UUID

    @State private var showSource = false
    @State private var picker: PlanPicker?
    @State private var activeDrag: (id: UUID, x: Double, y: Double)?
    @State private var navSnagID: UUID?

    private var room: Room? { store.rooms.first { $0.id == roomID } }
    private var snags: [Snag] { store.snags.filter { $0.roomID == roomID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let room = room {
                    Text("Pin every defect to its spot on the room photo.")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)

                    planArea(room)

                    HStack(spacing: 10) {
                        ActionButton(title: room.planPhotoFileName == nil ? "Add Photo" : "Replace Photo",
                                     systemImage: "camera.fill", kind: .secondary) { showSource = true }
                        if room.planPhotoFileName != nil {
                            ActionButton(title: "Remove", systemImage: "trash", kind: .secondary) {
                                store.setRoomPlanPhoto(room, fileName: nil)
                            }
                        }
                    }

                    SectionHeader(title: "Snags in this room", subtitle: "\(snags.count) total")
                    if snags.isEmpty {
                        CardView { EmptyStateView(systemImage: "mappin.slash", title: "No snags",
                                                  message: "Add snags to this room to place markers.") }
                    } else {
                        ForEach(snags) { SnagRow(snag: $0, showRoom: false) }
                    }
                }
                // Hidden programmatic link used when a pin is tapped.
                NavigationLink(
                    destination: Group { if let id = navSnagID { SnagDetailView(snagID: id) } },
                    isActive: Binding(get: { navSnagID != nil }, set: { if !$0 { navSnagID = nil } })
                ) { EmptyView() }.hidden()
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Plan Marker", displayMode: .inline)
        .actionSheet(isPresented: $showSource) {
            ActionSheet(title: Text("Room photo / plan"), buttons: [
                .default(Text("Take Photo")) { picker = .camera },
                .default(Text("Choose from Library")) { picker = .library },
                .cancel()
            ])
        }
        .sheet(item: $picker) { kind in
            Group {
                if kind == .camera { CameraPicker { handle($0) } }
                else { PhotoLibraryPicker { handle($0) } }
            }
        }
    }

    private func planArea(_ room: Room) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h: CGFloat = 280
            ZStack {
                if let img = PhotoStore.shared.loadImage(named: room.planPhotoFileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: w, height: h).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surfaceAlt)
                        .overlay(GridPattern(spacing: 26).stroke(Theme.gridLine.opacity(0.12), lineWidth: 0.6)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m)))
                        .overlay(VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 28)).foregroundColor(Theme.textSecondary)
                            Text("Add a room photo to pin on").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        })
                }
                ForEach(snags) { snag in
                    pin(snag, in: CGSize(width: w, height: h))
                }
            }
            .frame(width: w, height: h)
        }
        .frame(height: 280)
    }

    private func pin(_ snag: Snag, in size: CGSize) -> some View {
        let pos = position(snag, in: size)
        return Image(systemName: "mappin.circle.fill")
            .font(.system(size: 30))
            .foregroundColor(snag.severity.color)
            .background(Circle().fill(Color.white).frame(width: 13, height: 13))
            .shadow(color: Theme.shadow, radius: 3, y: 1)
            .scaleEffect(activeDrag?.id == snag.id ? 1.3 : 1)
            .position(pos)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let nx = Double(min(max(v.location.x / size.width, 0), 1))
                        let ny = Double(min(max(v.location.y / size.height, 0), 1))
                        activeDrag = (snag.id, nx, ny)
                    }
                    .onEnded { v in
                        let moved = hypot(v.translation.width, v.translation.height)
                        if moved < 8 {
                            activeDrag = nil
                            navSnagID = snag.id
                        } else if let d = activeDrag, d.id == snag.id {
                            store.updateMarker(snag, x: d.x, y: d.y)
                            activeDrag = nil
                        }
                    }
            )
    }

    private func position(_ snag: Snag, in size: CGSize) -> CGPoint {
        if let d = activeDrag, d.id == snag.id {
            return CGPoint(x: size.width * CGFloat(d.x), y: size.height * CGFloat(d.y))
        }
        return CGPoint(x: size.width * CGFloat(snag.marker.x), y: size.height * CGFloat(snag.marker.y))
    }

    private func handle(_ image: UIImage) {
        guard let room = room, let name = PhotoStore.shared.save(image) else { return }
        store.setRoomPlanPhoto(room, fileName: name)
    }
}
