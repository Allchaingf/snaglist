//
//  Charts.swift
//  Snaglist
//
//  Hand-drawn charts (Swift Charts is iOS 16+). Bar and donut, built with
//  Shape/Path/GeometryReader. iOS 14 safe.
//

import SwiftUI

struct ChartDatum: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    var color: Color = Theme.accent
}

// MARK: - Bar chart (vertical)

struct BarChartView: View {
    let data: [ChartDatum]
    var height: CGFloat = 160

    private var maxValue: Double { max(data.map { $0.value }.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(data) { d in
                VStack(spacing: 6) {
                    Text(Formatters.decimal(d.value, digits: 0))
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [d.color, d.color.opacity(0.55)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(CGFloat(d.value / maxValue) * height, 3))
                    Text(d.label)
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 36)
    }
}

// MARK: - Donut chart

struct DonutChartView: View {
    let data: [ChartDatum]
    var size: CGFloat = 150
    var lineWidth: CGFloat = 26
    var centerTitle: String? = nil
    var centerSubtitle: String = "total"

    private var total: Double { max(data.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        ZStack {
            if data.allSatisfy({ $0.value == 0 }) {
                Circle().stroke(Theme.stroke, lineWidth: lineWidth)
            } else {
                ForEach(Array(segments().enumerated()), id: \.offset) { _, seg in
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            VStack(spacing: 0) {
                Text(centerTitle ?? Formatters.decimal(total, digits: 0))
                    .font(Theme.title(20)).foregroundColor(Theme.textPrimary)
                Text(centerSubtitle).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func segments() -> [(start: CGFloat, end: CGFloat, color: Color)] {
        var result: [(CGFloat, CGFloat, Color)] = []
        var running: Double = 0
        for d in data {
            let start = running / total
            running += d.value
            let end = running / total
            result.append((CGFloat(start), CGFloat(end), d.color))
        }
        return result
    }
}

// MARK: - Legend

struct ChartLegend: View {
    let items: [ChartDatum]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle().fill(item.color).frame(width: 9, height: 9)
                    Text(item.label).font(Theme.caption()).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(Formatters.decimal(item.value, digits: 0))
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
