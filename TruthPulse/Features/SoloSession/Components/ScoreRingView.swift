//
//  ScoreRingView.swift
//  TruthPulse
//
//  誠実度スコアのリング。1.1 秒周期の二段ビートで脈動します。
//

import SwiftUI

struct ScoreRingView: View {
    let score: Int
    let progress: Double
    /// 1 拍ごとに increment される値。これが変わると脈動が走る。
    let heartbeatTick: Int
    var accent: Color?
    var caption: String = "誠実度"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beatScale: CGFloat = 1

    private let diameter: CGFloat = 196
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // トラック
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

            // 進捗
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(ringStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: progress)

            // 内側の破線ガイド
            Circle()
                .inset(by: lineWidth + 4)
                .stroke(TPColor.cyan.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 6]))

            VStack(spacing: 9) {
                Text(String(score))
                    .font(TPFont.score(56))
                    .tracking(-2.5)
                    .foregroundStyle(TPColor.textPrimary)
                    .contentTransition(.numericText())
                    .scaleEffect(beatScale)

                Text(caption)
                    .tpLabelStyle(size: 10)
            }
        }
        .frame(width: diameter, height: diameter)
        .onChange(of: heartbeatTick) { _, _ in pulse() }
        // MARK: Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue("誠実度 " + String(score) + " パーセント")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var ringStyle: AngularGradient {
        AngularGradient(
            colors: accent.map { [$0.opacity(0.65), $0, $0] }
                ?? [TPColor.cyan, TPColor.electric, TPColor.purple, TPColor.cyan],
            center: .center
        )
    }

    /// 収縮期 → 拡張期を模した非対称の二段ビート。
    private func pulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.13)) { beatScale = 1.045 }
        withAnimation(.easeInOut(duration: 0.15).delay(0.13)) { beatScale = 1.0 }
        withAnimation(.easeOut(duration: 0.10).delay(0.28)) { beatScale = 1.02 }
        withAnimation(.easeInOut(duration: 0.22).delay(0.38)) { beatScale = 1.0 }
    }
}

#Preview {
    @Previewable @State var tick = 0

    ZStack {
        TPColor.backdrop
        ScoreRingView(score: 72, progress: 0.72, heartbeatTick: tick)
    }
    .preferredColorScheme(.dark)
    .task {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1_100))
            tick += 1
        }
    }
}
