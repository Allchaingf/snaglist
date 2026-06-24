//
//  SettingsView.swift  (Screen 14 — Settings)
//  Snaglist
//
//  Theme, enabled trades, severity colors, currency, backup/export and data
//  reset — all wired to real persistence and behavior. Not a user profile.
//  iOS 14 safe.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage("currencyCode") private var currencyRaw = CurrencyCode.usd.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var confirm: ConfirmAction?
    @State private var shareURL: ShareURL?
    @State private var toast: String?

    enum ConfirmAction: Int, Identifiable { case reset, wipe; var id: Int { rawValue } }
    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    private var currentCurrency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let t = toast {
                    CardView { HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.closed)
                        Text(t).font(Theme.body()).foregroundColor(Theme.textPrimary) } }
                }

                // Appearance
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Appearance", subtitle: "Applies instantly", systemImage: "circle.lefthalf.filled")
                        Picker("", selection: $appearanceRaw) {
                            ForEach(AppAppearance.allCases) { Text($0.displayName).tag($0.rawValue) }
                        }.pickerStyle(SegmentedPickerStyle())
                    }
                }

                // Trades
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Trades", subtitle: "Categories offered when adding a snag", systemImage: "hammer.fill")
                        ForEach(Trade.allCases) { trade in
                            Toggle(isOn: Binding(
                                get: { store.project.enabledTrades.contains(trade) },
                                set: { on in
                                    var set = Set(store.project.enabledTrades)
                                    if on { set.insert(trade) } else { set.remove(trade) }
                                    store.setEnabledTrades(Array(set))
                                })) {
                                Label(trade.displayName, systemImage: trade.icon)
                                    .font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: trade.color))
                        }
                    }
                }

                // Severity colors
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Severity colors", subtitle: "Applies across the whole app", systemImage: "paintpalette.fill")
                        Picker("", selection: Binding(get: { store.severityPalette }, set: { store.setSeverityPalette($0) })) {
                            ForEach(SeverityPalette.allCases) { Text($0.displayName).tag($0) }
                        }.pickerStyle(SegmentedPickerStyle())
                        HStack(spacing: 10) {
                            ForEach(Severity.allCases) { sev in
                                HStack(spacing: 6) {
                                    Circle().fill(sev.color).frame(width: 14, height: 14)
                                    Text(sev.displayName).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                }.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                // Currency
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Currency", subtitle: "Used for any cost notes", systemImage: "dollarsign.circle.fill")
                        Picker("", selection: $currencyRaw) {
                            ForEach(CurrencyCode.allCases) { Text($0.displayName).tag($0.rawValue) }
                        }.pickerStyle(MenuPickerStyle()).accentColor(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                        Text("Example: \(Formatters.currency(1250, code: currentCurrency.code, symbol: currentCurrency.symbol))")
                            .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                }

                // Backup / data
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Backup & Data", systemImage: "tray.full.fill")
                        ActionButton(title: "Export Data (JSON)", systemImage: "square.and.arrow.up", kind: .secondary) { exportData() }
                        ActionButton(title: "Replay Onboarding", systemImage: "sparkles", kind: .secondary) {
                            hasCompletedOnboarding = false
                            flash("Onboarding will show on next launch")
                        }
                        ActionButton(title: "Reset Sample Data", systemImage: "arrow.counterclockwise") { confirm = .reset }
                        ActionButton(title: "Clear All Data", systemImage: "trash", kind: .danger) { confirm = .wipe }
                    }
                }

                // About
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "About", systemImage: "info.circle.fill")
                        aboutRow("App", "Snag List")
                        aboutRow("Version", "1.0")
                        aboutRow("Mode", "Offline · No account")
                        Text("Snag List keeps your acceptance inspection on-device — catch every snag before handover.")
                            .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Settings", displayMode: .inline)
        .actionSheet(item: $confirm) { action in confirmSheet(action) }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
    }

    // MARK: - Helpers

    private func aboutRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(Theme.body()).foregroundColor(Theme.textSecondary)
            Spacer(); Text(v).font(Theme.body()).foregroundColor(Theme.textPrimary) }
    }

    private func flash(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { toast = nil } }
    }

    private func exportData() {
        if let url = store.exportURL() { shareURL = ShareURL(url: url) }
        else { flash("Nothing to export yet") }
    }

    private func confirmSheet(_ action: ConfirmAction) -> ActionSheet {
        switch action {
        case .reset:
            return ActionSheet(title: Text("Reset to Sample Data?"),
                               message: Text("This replaces all current data with the demo inspection."),
                               buttons: [.destructive(Text("Reset")) { store.resetToSampleData(); flash("Sample data restored") }, .cancel()])
        case .wipe:
            return ActionSheet(title: Text("Clear All Data?"),
                               message: Text("This permanently deletes every room, snag and photo on this device."),
                               buttons: [.destructive(Text("Delete Everything")) { store.wipeAll(); flash("All data cleared") }, .cancel()])
        }
    }
}
