//
//  SnaglistApp.swift
//  Snaglist
//
//  App entry point. Injects the global AppStore + NotificationManager, applies
//  the persisted theme (light/dark/system) and flushes data to disk on
//  backgrounding. iOS 14 safe.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct SnaglistApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(notifications)
                .preferredColorScheme(appearance.colorScheme)
                .onAppear { configureGlobalAppearance() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.flush() }
        }
    }

    /// Clear List/Form table backgrounds (UITableView-backed on iOS 14) so the
    /// inspection backdrop shows through, and make navigation bars transparent.
    private func configureGlobalAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITextView.appearance().backgroundColor = .clear   // TextEditor backdrop shows the card

        let titleColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xE8EEF6) : UIColor(hex: 0x0F172A) }
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: titleColor]
        nav.largeTitleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x2563EB)
    }
}
