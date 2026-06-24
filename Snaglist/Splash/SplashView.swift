//
//  SplashView.swift
//  Snaglist
//
//  Thematic launch animation: a RED defect flag draws itself in, then MORPHS
//  into a GREEN check (the whole "open → verified" idea in one motion). Three+
//  simultaneously animated layers: (1) gradient + grid shimmer sweep,
//  (2) the badge flag→check morph, (3) the logo + title spring entrance, with a
//  designed scale-up/fade exit. A single coordinator Timer drives the staged
//  sequence; every looping animation is torn down in onDisappear. iOS 14 safe.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // Loop teardown flag
    @State private var isVisible = true

    // Staged reveals
    @State private var showBackdrop = false
    @State private var showBadge = false
    @State private var drawFlag: CGFloat = 0
    @State private var morph = false           // flag -> check
    @State private var drawCheck: CGFloat = 0
    @State private var showTitle = false
    @State private var exiting = false

    // Looping layers
    @State private var shimmer = false
    @State private var pulse = false

    // Single coordinator timer
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    private var badgeColor: Color { morph ? Theme.closed : Theme.flag }

    var body: some View {
        ZStack {
            // ---- Layer 1: background gradient + grid + shimmer sweep ----
            Theme.background.ignoresSafeArea()

            GridPattern(spacing: 32)
                .stroke(Theme.gridLine.opacity(showBackdrop ? 0.10 : 0), lineWidth: 0.8)
                .ignoresSafeArea()

            LinearGradient(colors: [.clear, Theme.accent.opacity(0.16), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 240)
                .rotationEffect(.degrees(22))
                .offset(x: shimmer ? 320 : -320, y: shimmer ? 220 : -220)
                .ignoresSafeArea()
                .opacity(showBackdrop ? 1 : 0)

            // ---- Layer 2: the flag -> check morph badge ----
            VStack(spacing: 26) {
                ZStack {
                    // soft glow ring
                    Circle()
                        .fill((morph ? Theme.okGlow : Theme.flagGlow))
                        .frame(width: 168, height: 168)
                        .scaleEffect(pulse ? 1.06 : 0.96)

                    Circle()
                        .fill(badgeColor)
                        .frame(width: 120, height: 120)
                        .shadow(color: badgeColor.opacity(0.5), radius: 16, y: 8)

                    // the defect flag (fades out as it morphs)
                    FlagShape()
                        .trim(from: 0, to: drawFlag)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .frame(width: 56, height: 60)
                        .opacity(morph ? 0 : 1)

                    // the closure check (draws in during the morph)
                    CheckShape()
                        .trim(from: 0, to: drawCheck)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        .frame(width: 58, height: 58)
                        .opacity(morph ? 1 : 0)
                }
                .scaleEffect(showBadge ? (exiting ? 1.5 : 1) : 0.4)
                .opacity(showBadge ? (exiting ? 0 : 1) : 0)

                // ---- Layer 3: logo title + tagline ----
                VStack(spacing: 6) {
                    Text("SNAG LIST")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .tracking(3)
                    Text("Catch every snag before handover.")
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(showTitle ? (exiting ? 0 : 1) : 0)
                .offset(y: showTitle ? 0 : 18)
            }
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: - Animation control

    private func start() {
        isVisible = true
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { shimmer = true }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }

        elapsed = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isVisible else { return }
        if elapsed >= 0.1 && !showBackdrop {
            withAnimation(.easeOut(duration: 0.6)) { showBackdrop = true }
        }
        if elapsed >= 0.5 && !showBadge {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showBadge = true }
            withAnimation(.easeInOut(duration: 0.8)) { drawFlag = 1 }
        }
        if elapsed >= 1.3 && !morph {
            withAnimation(.easeInOut(duration: 0.5)) { morph = true }
            withAnimation(.easeInOut(duration: 0.7)) { drawCheck = 1 }
        }
        if elapsed >= 2.0 && !showTitle {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { showTitle = true }
        }
        if elapsed >= 2.6 && !exiting {
            withAnimation(.easeIn(duration: 0.45)) { exiting = true }
        }
        if elapsed >= 3.05 {
            timer?.invalidate(); timer = nil
            onFinish()
        }
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        // Reset every loop/state var so nothing leaks into the main app.
        shimmer = false; pulse = false
        showBackdrop = false; showBadge = false; showTitle = false
        morph = false; exiting = false
        drawFlag = 0; drawCheck = 0
    }
}
