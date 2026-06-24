//
//  HandoverReadinessView.swift  (Screen 09 — Handover Readiness)
//  Snaglist
//
//  The overall readiness %, a status donut, and exactly what blocks handover
//  (unverified criticals). Gates the route to Sign-off. iOS 14 safe.
//

import SwiftUI

struct HandoverReadinessView: View {
    @EnvironmentObject var store: AppStore

    private var statusData: [ChartDatum] {
        let c = store.statusCounts()
        return [
            ChartDatum(label: "Verified", value: Double(c[.verified] ?? 0), color: Theme.closed),
            ChartDatum(label: "Fixed", value: Double(c[.fixed] ?? 0), color: Theme.review),
            ChartDatum(label: "Open", value: Double((c[.open] ?? 0) + (c[.reopened] ?? 0)), color: Theme.flag)
        ]
    }

    var body: some View {
        ScreenScaffold("Handover", subtitle: store.project.name) {
            // Readiness hero
            CardView {
                VStack(spacing: Theme.Space.m) {
                    ProgressRing(progress: store.handoverReadiness, size: 132, lineWidth: 14,
                                 tint: store.canHandover ? Theme.closed : Theme.accent)
                    Text(store.canHandover ? "Ready for handover" : "Not ready yet")
                        .font(Theme.heading(17))
                        .foregroundColor(store.canHandover ? Theme.closed : Theme.textPrimary)
                    Text("\(store.statusCounts()[.verified] ?? 0) of \(store.totalSnags) snags verified · handover \(Formatters.relativeDays(to: store.project.handoverDate))")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                }
            }

            // Status breakdown
            CardView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    SectionHeader(title: "Status breakdown", systemImage: "chart.pie.fill")
                    HStack(spacing: Theme.Space.l) {
                        DonutChartView(data: statusData, size: 130, lineWidth: 22,
                                       centerTitle: Formatters.percent(store.handoverReadiness), centerSubtitle: "ready")
                        ChartLegend(items: statusData)
                    }
                }
            }

            // Blockers
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Blocks handover",
                                  subtitle: store.blockingCriticals.isEmpty ? "No critical snags open" : "Unverified critical snags",
                                  systemImage: "exclamationmark.octagon.fill")
                    if store.blockingCriticals.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.closed)
                            Text("No critical defects are blocking handover.").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                    } else {
                        ForEach(store.blockingCriticals) { SnagRow(snag: $0) }
                    }
                }
            }

            // Proceed to sign-off (gated on no blocking criticals)
            NavigationLink(destination: SignOffView()) {
                ActionLabel(title: store.signoff?.accepted == true ? "View Sign-off" : "Proceed to Sign-off",
                            systemImage: "signature", kind: .verify)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!store.blockingCriticals.isEmpty)
            .opacity(store.blockingCriticals.isEmpty ? 1 : 0.5)

            if !store.blockingCriticals.isEmpty {
                Text("Resolve and verify the critical snags above before sign-off.")
                    .font(Theme.caption(11)).foregroundColor(Theme.flag)
            }
        }
    }
}
