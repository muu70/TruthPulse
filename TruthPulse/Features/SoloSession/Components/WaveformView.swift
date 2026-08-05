//
//  WaveformView.swift
//  TruthPulse
//
//  生体波形。Canvas で毎フレーム描画します（View の再構築を避けるため）。
//

import SwiftUI

struct WaveformView: View {
    let samples: [Double]
    var color: Color = TPColor.cyan
    var isLive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }

            let midY = size.height / 2
            let stepX = size.width / CGFloat(samples.count - 1)
            let amplitude = size.height * 0.42

            var path = Path()
            for (index, value) in samples.enumerated() {
                let point = CGPoint(
                    x: CGFloat(index) * stepX,
                    y: midY - CGFloat(value) * amplitude
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }

            // 発光レイヤー。フィルタを足す前のコンテキストを控えておく。
            let sharp = context
            context.addFilter(.blur(radius: 4))
            context.stroke(path, with: .color(color.opacity(0.55)), lineWidth: 3)

            sharp.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 52)
        .background {
            GlassBackground(cornerRadius: 16)
        }
        .overlay(alignment: .leading) {
            // 中心線
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("生体波形")
        .accessibilityValue(isLive ? "計測中" : "停止中")
    }
}

#Preview {
    @Previewable @State var samples: [Double] = Array(repeating: 0, count: 120)
    let engine = BioSignalEngine(seed: 42)

    ZStack {
        TPColor.backdrop
        WaveformView(samples: samples)
            .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
    .task {
        var t: TimeInterval = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            t += 0.05
            samples.removeFirst()
            samples.append(engine.waveform(at: t, agitation: 0.2))
        }
    }
}
