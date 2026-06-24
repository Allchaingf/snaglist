//
//  BySeverityView.swift  (Screen 06 — By Severity)
//  Snaglist
//
//  Snags grouped by severity, criticals first, with an "unverified only" filter.
//  iOS 14 safe.
//

import SwiftUI

struct BySeverityView: View {
    @EnvironmentObject var store: AppStore
    @State private var unverifiedOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Picker("", selection: $unverifiedOnly) {
                    Text("All").tag(false)
                    Text("Unverified only").tag(true)
                }.pickerStyle(SegmentedPickerStyle())

                let groups = store.snagsBySeverity(unverifiedOnly: unverifiedOnly)
                if groups.isEmpty {
                    CardView { EmptyStateView(systemImage: "checkmark.seal",
                                              title: unverifiedOnly ? "All clear" : "No snags",
                                              message: unverifiedOnly ? "Nothing is waiting — every snag is verified."
                                                                      : "Add snags to see them ranked by severity.") }
                } else {
                    ForEach(groups, id: \.severity) { group in
                        HStack(spacing: 8) {
                            Image(systemName: group.severity.icon).foregroundColor(group.severity.color)
                            Text(group.severity.displayName).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Text("· \(group.snags.count)").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                        ForEach(group.snags) { SnagRow(snag: $0) }
                    }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("By Severity", displayMode: .inline)
    }
}
