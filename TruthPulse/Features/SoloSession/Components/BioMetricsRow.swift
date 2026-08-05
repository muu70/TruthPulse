//
//  BioMetricsRow.swift
//  TruthPulse
//
//  Pulse / Micro-T / Stress の 3 連メトリクス。
//  Dynamic Type が AX サイズになると自動で 1 列に折り返します。
//

import SwiftUI

struct BioMetricsRow: View {
    let pulse: Int
    let microTremor: Double
    let stress: Int

    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            MetricTile(key: "心拍", value: String(pulse), unit: "bpm",
                       a11y: "心拍数 " + String(pulse) + " bpm")
            MetricTile(key: "微振動", value: String(format: "%.1f", microTremor), unit: "Δ",
                       a11y: "微振動 " + String(format: "%.1f", microTremor))
            MetricTile(key: "緊張度", value: String(stress), unit: "%",
                       a11y: "緊張度 " + String(stress) + " パーセント")
        }
    }
}

private struct MetricTile: View {
    let key: String
    let value: String
    let unit: String
    let a11y: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .tpLabelStyle(size: 10)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(TPFont.mono(19))
                    .foregroundStyle(TPColor.textPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TPColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 10)
        .background { GlassBackground(cornerRadius: 16) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        BioMetricsRow(pulse: 86, microTremor: 0.4, stress: 31)
            .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
