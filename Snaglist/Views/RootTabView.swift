//
//  RootTabView.swift
//  Snaglist
//
//  Main app shell: a custom tab bar + per-tab NavigationView stacks. The Queues
//  and More tabs are hub screens linking the remaining views. Also defines the
//  reusable NavRow and SnagRow used across the app. iOS 14 safe.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .rooms

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .rooms:    stack { RoomWalkthroughView() }
                case .queues:   stack { QueuesHubView() }
                case .handover: stack { HandoverReadinessView() }
                case .history:  stack { HistoryView() }
                case .more:     stack { MoreView() }
                }
            }
            CustomTabBar(selection: $tab, badges: [
                .queues: store.verifyQueue.count,
                .handover: store.openCriticalCount
            ])
        }
    }

    private func stack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        NavigationView { content() }
            .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Reusable navigation row (card style)

struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var tint: Color = Theme.accent
    var badge: Int = 0
    let destination: Destination

    init(icon: String, title: String, subtitle: String = "", tint: Color = Theme.accent,
         badge: Int = 0, @ViewBuilder destination: () -> Destination) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.tint = tint; self.badge = badge; self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: icon).foregroundColor(tint).font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                if badge > 0 { TagChip(text: "\(badge)", color: Theme.flag, filled: true) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reusable snag row (links to detail)

struct SnagRow: View {
    let snag: Snag
    var showRoom: Bool = true
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationLink(destination: SnagDetailView(snagID: snag.id)) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 5) {
                    Text(snag.title.isEmpty ? "Untitled snag" : snag.title)
                        .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        TagChip(text: snag.severity.displayName, color: snag.severity.color, systemImage: snag.severity.icon)
                        TagChip(text: snag.trade.displayName, color: snag.trade.color, systemImage: snag.trade.icon)
                    }
                    HStack(spacing: 6) {
                        if showRoom {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                            Text(store.roomName(snag.roomID)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        }
                        if snag.isOverdue {
                            TagChip(text: "Overdue", color: Theme.flag, systemImage: "clock.fill")
                        }
                    }
                }
                Spacer(minLength: 6)
                statusBadge
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var thumbnail: some View {
        ZStack {
            if let img = PhotoStore.shared.loadImage(named: snag.photoFileName) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10).fill(snag.trade.color.opacity(0.16)).frame(width: 48, height: 48)
                    .overlay(Image(systemName: snag.trade.icon).foregroundColor(snag.trade.color))
            }
        }
    }

    private var statusBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: snag.status.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(snag.status.color)
            Text(snag.status.displayName).font(Theme.caption(9)).foregroundColor(snag.status.color)
        }
        .frame(width: 56)
    }
}

// MARK: - Queues hub

struct QueuesHubView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("Queues", subtitle: "Hand work to crews & verify fixes") {
            CardView {
                HStack {
                    summary("\(store.totalOpen)", "Open", Theme.flag)
                    Divider().frame(height: 34)
                    summary("\(store.verifyQueue.count)", "To verify", Theme.review)
                    Divider().frame(height: 34)
                    summary("\(store.statusCounts()[.verified] ?? 0)", "Verified", Theme.closed)
                }
            }
            VStack(spacing: 12) {
                NavRow(icon: "checkmark.circle.badge.questionmark", title: "Verify Queue",
                       subtitle: "Fixes awaiting your re-check", tint: Theme.review,
                       badge: store.verifyQueue.count) { VerifyQueueView() }
                NavRow(icon: "hammer.fill", title: "By Trade",
                       subtitle: "Group snags for each crew", tint: Theme.accent) { ByTradeView() }
                NavRow(icon: "exclamationmark.triangle.fill", title: "By Severity",
                       subtitle: "Criticals first", tint: Theme.flag) { BySeverityView() }
                NavRow(icon: "person.2.fill", title: "By Assignee",
                       subtitle: "\(store.assignees.count) people · who owes what", tint: Theme.closed) { AssigneeView() }
            }
        }
    }

    private func summary(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.title(22)).foregroundColor(tint)
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - More hub

struct MoreView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("More", subtitle: store.project.name) {
            SectionHeader(title: "Documents", systemImage: "doc.text.fill")
            VStack(spacing: 12) {
                NavRow(icon: "doc.richtext.fill", title: "Reports",
                       subtitle: "Export the acceptance act (PDF)", tint: Theme.accent) { ReportsView() }
                NavRow(icon: "signature", title: "Sign-off",
                       subtitle: store.signoff?.accepted == true ? "Accepted" : "Final acceptance & signature",
                       tint: Theme.closed) { SignOffView() }
            }

            SectionHeader(title: "Setup", systemImage: "gearshape.fill")
            VStack(spacing: 12) {
                NavRow(icon: "person.crop.circle.badge.plus", title: "Assignees",
                       subtitle: "\(store.assignees.count) people", tint: Theme.accent) { AssigneeView() }
                NavRow(icon: "bell.badge.fill", title: "Reminders",
                       subtitle: "Fix-due, re-verify & handover alerts", tint: Theme.review) { RemindersView() }
                NavRow(icon: "slider.horizontal.3", title: "Settings",
                       subtitle: "Theme, trades, severity colors, backup", tint: Theme.textSecondary) { SettingsView() }
            }
        }
    }
}
