//
//  Theme.swift
//  Snaglist
//
//  Central design system: the light, "inspector" red/green palette (with dark
//  counterparts so System/Light/Dark all work), gradients, typography, spacing
//  tokens and cached formatters. Every API here is iOS 14.0 safe.
//

import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    /// Builds a color that adapts to the active interface style. The app-wide
    /// `preferredColorScheme` (driven from Settings) flips these automatically.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt, alpha: Double = 1.0) {
        self = Color(UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}

// MARK: - Theme namespace

enum Theme {

    // Surfaces / backgrounds (light spec values + dark counterparts)
    static let bgTop      = Color.dynamic(light: 0xF8FAFB, dark: 0x0B1220)
    static let bgBottom   = Color.dynamic(light: 0xEEF2F5, dark: 0x111A29)
    static let surface    = Color.dynamic(light: 0xFFFFFF, dark: 0x1A2536)
    static let surfaceAlt = Color.dynamic(light: 0xEEF2F5, dark: 0x131C2B)
    static let hover      = Color.dynamic(light: 0xF2F6F9, dark: 0x1E2B3F)
    static let stroke     = Color.dynamic(light: 0xE0E7EC, dark: 0x2A3850)

    // Faint grid line for the inspection backdrop
    static let gridLine   = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)

    // Text
    static let textPrimary   = Color.dynamic(light: 0x0F172A, dark: 0xE8EEF6)
    static let textSecondary = Color.dynamic(light: 0x475569, dark: 0x94A3B8)
    static let textDisabled  = Color.dynamic(light: 0x94A3B8, dark: 0x5A6E86)
    static let textOnAccent  = Color(hex: 0xFFFFFF)

    // Brand / primary (inspector blue)
    static let accent       = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)
    static let accentActive = Color.dynamic(light: 0x1D4ED8, dark: 0x3B82F6)
    static let accentSoft    = Color(hex: 0x60A5FA)

    // Semantic — the inspector red/green system
    static let flag    = Color.dynamic(light: 0xEF4444, dark: 0xF87171)  // defect / open
    static let closed  = Color.dynamic(light: 0x22C55E, dark: 0x4ADE80)  // verified / closed
    static let review  = Color.dynamic(light: 0xF59E0B, dark: 0xFBBF24)  // on review / fixed
    static let success = Color.dynamic(light: 0x22C55E, dark: 0x4ADE80)
    static let warning = Color.dynamic(light: 0xF59E0B, dark: 0xFBBF24)
    static let danger  = Color.dynamic(light: 0xEF4444, dark: 0xF87171)
    static let info    = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)

    // Glows (per spec)
    static let flagGlow = Color(hex: 0xEF4444, alpha: 0.20)
    static let okGlow   = Color(hex: 0x22C55E, alpha: 0.20)
    static let shadow   = Color(hex: 0x0F172A, alpha: 0.08)

    // Gradients
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentActive],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var verifyGradient: LinearGradient {
        LinearGradient(colors: [closed, Color.dynamic(light: 0x16A34A, dark: 0x22C55E)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var flagGradient: LinearGradient {
        LinearGradient(colors: [flag, Color.dynamic(light: 0xDC2626, dark: 0xEF4444)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Spacing scale
    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // Corner radii
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // Typography (system fonts, rounded & weighted)
    static func title(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat = 19) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Formatters (cached; .formatted() is iOS 15+, so we never use it)

enum Formatters {
    static func currency(_ value: Double, code: String, symbol: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.currencySymbol = symbol
        f.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? "\(symbol)\(Int(value))"
    }

    static func decimal(_ value: Double, digits: Int = 1) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    private static let medium: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let shortDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let dateTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    static func date(_ d: Date) -> String { medium.string(from: d) }
    static func dayMonth(_ d: Date) -> String { shortDay.string(from: d) }
    static func dateTime(_ d: Date) -> String { dateTimeFmt.string(from: d) }

    static func relativeDays(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days > 0 { return "in \(days)d" }
        return "\(-days)d overdue"
    }
}

// MARK: - Keyboard dismissal (no @FocusState on iOS 14)

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
