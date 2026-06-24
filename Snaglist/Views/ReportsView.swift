//
//  ReportsView.swift  (Screen 11 — Reports)
//  Snaglist
//
//  Compose an acceptance report (by room / trade / severity, % closed) and
//  export a real PDF "act" via UIGraphicsPDFRenderer + share sheet. The PDF
//  builder (AcceptancePDF) is reused by Sign-off. iOS 14 safe (NSAttributedString
//  drawing, no Swift AttributedString).
//

import SwiftUI
import UIKit

enum ReportSection: String, CaseIterable, Identifiable {
    case overview, byRoom, byTrade, bySeverity, openClosed, history
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .byRoom: return "By Room"
        case .byTrade: return "By Trade"
        case .bySeverity: return "By Severity"
        case .openClosed: return "Open vs Closed"
        case .history: return "History Log"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "doc.text.fill"
        case .byRoom: return "square.grid.2x2.fill"
        case .byTrade: return "hammer.fill"
        case .bySeverity: return "exclamationmark.triangle.fill"
        case .openClosed: return "checkmark.circle.fill"
        case .history: return "clock.arrow.circlepath"
        }
    }

    /// Bullet lines for both the on-screen preview and the PDF.
    func lines(_ store: AppStore) -> [String] {
        switch self {
        case .overview:
            let c = store.statusCounts()
            return [
                "Project: \(store.project.name)",
                "Type: \(store.project.type.displayName)" + (store.project.clientName.isEmpty ? "" : " · Client: \(store.project.clientName)"),
                "Handover: \(Formatters.date(store.project.handoverDate)) (\(Formatters.relativeDays(to: store.project.handoverDate)))",
                "Snags: \(store.totalSnags) total · \(store.totalOpen) open · \(c[.verified] ?? 0) verified",
                "Handover readiness: \(Formatters.percent(store.handoverReadiness))",
                "Open critical defects: \(store.openCriticalCount)"
            ]
        case .byRoom:
            return store.rooms.map { r in
                "\(r.name): \(store.openCount(in: r)) open / \(store.snags(in: r).count) total — \(Formatters.percent(store.readiness(of: r))) ready"
            }
        case .byTrade:
            return store.snagsByTrade().map { g in
                "\(g.trade.displayName): \(g.snags.count) snags, \(g.snags.filter { $0.isOpen }.count) open"
            }
        case .bySeverity:
            return Severity.allCases.reversed().map { s in
                let all = store.count(s)
                let unverified = store.snags.filter { $0.severity == s && $0.status != .verified }.count
                return "\(s.displayName): \(all) total, \(unverified) unverified"
            }
        case .openClosed:
            let c = store.statusCounts()
            return [
                "Open: \(c[.open] ?? 0)",
                "Reopened: \(c[.reopened] ?? 0)",
                "Fixed (awaiting verify): \(c[.fixed] ?? 0)",
                "Verified (closed): \(c[.verified] ?? 0)",
                "Closed: \(Formatters.percent(store.percentClosed))"
            ]
        case .history:
            return store.history.prefix(20).map { e in
                "\(Formatters.dateTime(e.timestamp)) — \(e.action.displayName): \(e.snagTitle)"
            }
        }
    }
}

// MARK: - PDF builder (shared with Sign-off)

enum AcceptancePDF {
    static func make(store: AppStore, sections: [ReportSection],
                     signature: UIImage?, signatureName: String, fileName: String) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor(hex: 0x0F172A)]
        let sectionAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor(hex: 0x2563EB)]
        let bodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor(hex: 0x222222)]
        let metaAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(hex: 0x888888)]

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()

                func ensure(_ h: CGFloat) { if y + h > pageH - margin { ctx.beginPage(); y = margin } }
                func draw(_ text: String, _ attr: [NSAttributedString.Key: Any], _ height: CGFloat) {
                    ensure(height)
                    (text as NSString).draw(in: CGRect(x: margin, y: y, width: pageW - margin * 2, height: height), withAttributes: attr)
                    y += height
                }

                draw("Acceptance / Snag Report", titleAttr, 34)
                draw("Generated \(Formatters.date(Date())) · \(store.project.name)", metaAttr, 18)
                y += 6
                ctx.cgContext.setStrokeColor(UIColor(hex: 0xCCCCCC).cgColor)
                ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageW - margin, y: y)); ctx.cgContext.strokePath()
                y += 14

                for section in ReportSection.allCases where sections.contains(section) {
                    draw(section.title, sectionAttr, 24)
                    let lines = section.lines(store)
                    if lines.isEmpty { draw("•  (no data)", bodyAttr, 18) }
                    for line in lines { draw("•  " + line, bodyAttr, 18) }
                    y += 10
                }

                // Signature block
                if let sig = signature {
                    ensure(150)
                    draw("Customer Sign-off", sectionAttr, 24)
                    let sigRect = CGRect(x: margin, y: y, width: 220, height: 90)
                    sig.draw(in: sigRect)
                    ctx.cgContext.setStrokeColor(UIColor(hex: 0xCCCCCC).cgColor)
                    ctx.cgContext.stroke(sigRect)
                    y += 96
                    draw("Signed: \(signatureName.isEmpty ? "—" : signatureName) · \(Formatters.date(Date()))", bodyAttr, 18)
                }

                draw("Created with Snag List — offline acceptance inspection.", metaAttr, 16)
            }
            return url
        } catch { return nil }
    }
}

// MARK: - View

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selected: Set<ReportSection> = Set(ReportSection.allCases)
    @State private var generated = false
    @State private var shareURL: ShareURL?
    @State private var exportFailed = false

    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: 10) {
                    ActionButton(title: "Generate", systemImage: "doc.badge.gearshape") {
                        withAnimation { generated = true }
                    }
                    ActionButton(title: "Export PDF", systemImage: "square.and.arrow.up", kind: .secondary) { exportPDF() }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Include sections", systemImage: "checklist")
                        ForEach(ReportSection.allCases) { section in
                            Toggle(isOn: Binding(get: { selected.contains(section) },
                                                 set: { on in
                                                     if on { selected.insert(section) } else { selected.remove(section) }
                                                     generated = false
                                                 })) {
                                Label(section.title, systemImage: section.icon)
                                    .font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        }
                    }
                }

                if generated { preview }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Reports", displayMode: .inline)
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .alert(isPresented: $exportFailed) {
            Alert(title: Text("Export failed"), message: Text("Couldn't build the PDF. Try again."), dismissButton: .default(Text("OK")))
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preview", subtitle: "Tap Export PDF to share the act", systemImage: "doc.text.magnifyingglass")
            ForEach(ReportSection.allCases.filter { selected.contains($0) }) { section in
                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Image(systemName: section.icon).foregroundColor(Theme.accent)
                            Text(section.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary) }
                        let lines = section.lines(store)
                        if lines.isEmpty { Text("• (no data)").font(Theme.caption()).foregroundColor(Theme.textSecondary) }
                        ForEach(lines, id: \.self) { line in
                            Text("• " + line).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func exportPDF() {
        let ordered = ReportSection.allCases.filter { selected.contains($0) }
        if let url = AcceptancePDF.make(store: store, sections: ordered, signature: nil,
                                        signatureName: "", fileName: "SnagList-Report.pdf") {
            shareURL = ShareURL(url: url)
        } else { exportFailed = true }
    }
}
