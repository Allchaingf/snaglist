//
//  SignOffView.swift  (Screen 10 — Sign-off)
//  Snaglist
//
//  The final acceptance sheet: a readiness summary, customer/inspector names, a
//  local finger-drawn signature, and a PDF acceptance act export. All offline.
//  iOS 14 safe.
//

import SwiftUI

struct SignOffView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var signature = SignatureController()

    @State private var customerName = ""
    @State private var inspectorName = ""
    @State private var reSigning = false
    @State private var shareURL: ShareURL?
    @State private var exportFailed = false
    @State private var loaded = false

    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    private var isSigned: Bool { store.signoff?.accepted == true && !reSigning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                summaryCard
                if isSigned { signedCard } else { signingForm }
                exportButton
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Sign-off", displayMode: .inline)
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .alert(isPresented: $exportFailed) {
            Alert(title: Text("Export failed"), message: Text("Couldn't build the PDF. Try again."), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            guard !loaded else { return }
            customerName = store.signoff?.customerName ?? store.project.clientName
            inspectorName = store.signoff?.inspectorName ?? ""
            loaded = true
        }
    }

    // MARK: - Sections

    private var summaryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Acceptance summary", systemImage: "checkmark.seal.fill")
                summaryRow("Rooms", "\(store.rooms.count)")
                summaryRow("Snags", "\(store.totalSnags) total · \(store.totalOpen) open")
                summaryRow("Verified", "\(store.statusCounts()[.verified] ?? 0)")
                summaryRow("Readiness", Formatters.percent(store.handoverReadiness))
                if !store.canHandover {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.review)
                        Text(store.blockingCriticals.isEmpty
                             ? "Some snags are still open. You can sign off acknowledging them."
                             : "\(store.blockingCriticals.count) critical snag(s) still open.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private func summaryRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(Theme.body()).foregroundColor(Theme.textSecondary)
            Spacer(); Text(v).font(Theme.body()).foregroundColor(Theme.textPrimary) }
    }

    private var signingForm: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            LabeledField(label: "Customer name", text: $customerName, placeholder: "Person accepting")
            LabeledField(label: "Inspector name", text: $inspectorName, placeholder: "Person handing over")

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionHeader(title: "Customer signature", systemImage: "signature")
                        Spacer()
                        Button(action: { signature.clear() }) {
                            Label("Clear", systemImage: "eraser").font(Theme.caption(12)).foregroundColor(Theme.accent)
                        }
                    }
                    SignatureCanvas(controller: signature)
                        .frame(height: 180)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                    Text("Sign with your finger inside the box.").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }

            ActionButton(title: "Accept & Sign", systemImage: "checkmark.seal.fill", kind: .verify) { acceptAndSign() }
                .disabled(!canSign)
                .opacity(canSign ? 1 : 0.5)
            if !canSign {
                Text("Enter the customer name and draw a signature to accept.")
                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var signedCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundColor(Theme.closed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accepted").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                        if let s = store.signoff {
                            Text("\(s.customerName) · \(Formatters.dateTime(s.signedAt))")
                                .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                if let img = PhotoStore.shared.loadImage(named: store.signoff?.imageFileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(height: 120).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                }
                ActionButton(title: "Re-sign", systemImage: "arrow.counterclockwise", kind: .secondary) {
                    withAnimation { reSigning = true }
                }
            }
        }
    }

    private var exportButton: some View {
        ActionButton(title: "Export Acceptance PDF", systemImage: "square.and.arrow.up", kind: .primary) { exportPDF() }
    }

    // MARK: - Actions

    private var canSign: Bool {
        !customerName.trimmingCharacters(in: .whitespaces).isEmpty && signature.hasStrokes
    }

    private func acceptAndSign() {
        guard canSign, let img = signature.exportImage(), let name = PhotoStore.shared.savePNG(img) else { return }
        if let old = store.signoff?.imageFileName, old != name { PhotoStore.shared.delete(named: old) }
        let sig = Signature(imageFileName: name,
                            customerName: customerName.trimmingCharacters(in: .whitespaces),
                            inspectorName: inspectorName.trimmingCharacters(in: .whitespaces),
                            signedAt: Date(), accepted: true)
        store.saveSignoff(sig)
        withAnimation { reSigning = false }
    }

    private func exportPDF() {
        let sigImage = PhotoStore.shared.loadImage(named: store.signoff?.imageFileName)
        let name = store.signoff?.customerName ?? customerName
        if let url = AcceptancePDF.make(store: store, sections: ReportSection.allCases,
                                        signature: sigImage, signatureName: name,
                                        fileName: "SnagList-Acceptance.pdf") {
            shareURL = ShareURL(url: url)
        } else { exportFailed = true }
    }
}
