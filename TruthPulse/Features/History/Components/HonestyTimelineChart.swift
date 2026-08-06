//
//  HonestyTimelineChart.swift
//  TruthPulse
//
//  時間帯別の誠実度バーチャート。Swift Charts は型チェックが重く
//  ビルド時間に響くため（BACKLOG.md）、Canvas で自前描画しています。
//

import SwiftUI

struct HonestyTimelineChart: View {

    struct Bucket: Identifiable {
        /// 0–23 時
        let hour: Int
        let averageScore: Int
        let count: Int
        var id: Int { hour }
    }

    let buckets: [Bucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間帯別の誠実度").tpLabelStyle(size: 10)

            if buckets.isEmpty {
                placeholder
            } else {
                ZStack {
                    barsCanvas
                    accessibilityOverlay
                }
                .frame(height: 92)

                axisLabels
            }
        }
        .padding(16)
        .background { GlassBackground(cornerRadius: 18) }
    }

    // MARK: - Canvas

    private var barsCanvas: some View {
        Canvas { context, size in
            drawBars(context: context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func drawBars(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 6
        let count = CGFloat(buckets.count)
        let barWidth = max(2, (size.width - spacing * (count - 1)) / count)

        for (index, bucket) in buckets.enumerated() {
            let heightRatio = CGFloat(bucket.averageScore) / 100
            let barHeight = max(4, size.height * heightRatio)
            let x = CGFloat(index) * (barWidth + spacing)
            let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth, height: barHeight)
            let shape = Path(roundedRect: rect, cornerRadius: min(4, barWidth / 2))

            let tint = Verdict(score: bucket.averageScore).accentColor
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.55), tint]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
        }
    }

    // MARK: - Accessibility

    /// Canvas は 1 枚絵のため、VoiceOver で時間帯ごとに読み上げられるよう
    /// 透明な当たり判定を棒の数だけ重ねている。
    private var accessibilityOverlay: some View {
        HStack(spacing: 6) {
            ForEach(buckets) { bucket in
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(a11yLabel(for: bucket))
                    .accessibilityValue(String(bucket.count) + "件")
            }
        }
    }

    private func a11yLabel(for bucket: Bucket) -> String {
        String(bucket.hour) + "時台の平均は" + String(bucket.averageScore) + "点"
    }

    // MARK: - Axis

    private var axisLabels: some View {
        HStack(spacing: 6) {
            ForEach(buckets) { bucket in
                Text(String(bucket.hour))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(TPColor.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Text("この範囲にはまだ記録がありません")
            .font(TPFont.body(12.5))
            .foregroundStyle(TPColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        HonestyTimelineChart(buckets: [
            .init(hour: 20, averageScore: 44, count: 2),
            .init(hour: 21, averageScore: 72, count: 3),
            .init(hour: 22, averageScore: 36, count: 1),
            .init(hour: 23, averageScore: 88, count: 4)
        ])
        .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}

#Preview("空") {
    ZStack {
        TPColor.backdrop
        HonestyTimelineChart(buckets: [])
            .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
