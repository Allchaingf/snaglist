//
//  CustomTabBar.swift
//  Snaglist
//
//  Custom themed bottom tab bar (not the system TabView chrome) with per-tab
//  badges. iOS 14 safe (BlurView bridge instead of Material).
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case rooms, queues, handover, history, more
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .rooms: return "Rooms"
        case .queues: return "Queues"
        case .handover: return "Handover"
        case .history: return "History"
        case .more: return "More"
        }
    }
    var icon: String {
        switch self {
        case .rooms: return "square.grid.2x2.fill"
        case .queues: return "rectangle.stack.fill"
        case .handover: return "checkmark.seal.fill"
        case .history: return "clock.arrow.circlepath"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = tab }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(selection == tab ? Theme.accent : Theme.textSecondary)
                                .scaleEffect(selection == tab ? 1.12 : 1.0)
                            if let b = badges[tab], b > 0 {
                                Text("\(b)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Theme.flag))
                                    .offset(x: 13, y: -10)
                            }
                        }
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == tab ? Theme.accent : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(
            BlurView(style: .systemThinMaterial)
                .overlay(Theme.surface.opacity(0.6))
                .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}
