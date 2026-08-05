//
//  FactorBarRow.swift
//  TruthPulse
//
//  判定根拠の内訳バー 1 本。
//  色だけに依存させないため「項目名 + レベル文字 + バー長」の 3 重符号化。
//

import SwiftUI

struct FactorBarRow: View {
    let factor: AnalysisFactor
    let verdict: Verdict
    /// 0 = 未表示, 1 = 全開。親から順番に遅延させて伸ばす。
    var revealDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(factor.kind.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(TPColor.textSecondary)

                Spacer(minLength: 8)

                Text(factor.levelLabel)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.opacity)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))

                    Capsule()
                        .fill(
                            LinearGradient(colors: [tint.opacity(0.75), tint],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(4, proxy.size.width * fill))
                        .shadow(color: tint.opacity(0.5), radius: 8, y: 2)
                }
            }
            .frame(height: 6)
        }
        .task {
            guard !reduceMotion else {
                fill = factor.level
                return
            }
            try? await Task.sleep(for: .seconds(revealDelay))
            withAnimation(.easeOut(duration: 0.7)) { fill = factor.level }
        }
        // MARK: Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(factor.kind.title)
        .accessibilityValue(factor.levelLabel + "、" + String(Int(factor.level * 100)) + " パーセント")
    }

    /// 「高いほど疑わしい」項目と「高いほど良い」項目で色の意味が反転する。
    private var tint: Color {
        // 心拍の安定性だけは高い方が良い指標
        if factor.kind == .pulseStability {
            return factor.level >= 0.55 ? TPColor.truthText : TPColor.caution
        }

        if factor.level < 0.35 {
            return TPColor.truthText
        }
        if factor.level < 0.65 {
            return TPColor.caution
        }
        // 真実判定のときは高い値でもマゼンタまで振らず、琥珀に留める
        return verdict == .truthful ? TPColor.caution : TPColor.deceitText
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        VStack(spacing: 13) {
            FactorBarRow(factor: .init(kind: .microExpression, level: 0.82),
                         verdict: .deceptive, revealDelay: 0)
            FactorBarRow(factor: .init(kind: .perspiration, level: 0.56),
                         verdict: .deceptive, revealDelay: 0.1)
            FactorBarRow(factor: .init(kind: .pulseStability, level: 0.34),
                         verdict: .deceptive, revealDelay: 0.2)
            FactorBarRow(factor: .init(kind: .voiceTension, level: 0.64),
                         verdict: .deceptive, revealDelay: 0.3)
        }
        .glassCard(padding: 18)
        .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
