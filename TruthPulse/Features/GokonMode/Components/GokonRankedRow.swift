//
//  GokonRankedRow.swift
//  TruthPulse
//
//  ランキング1行ぶん。途中経過・最終ランキングの両方で使う。
//

import SwiftUI

struct GokonRankedRow: View {
    let rank: Int?
    let name: String
    let score: Int?

    var body: some View {
        HStack(spacing: 12) {
            rankLabel
            Text(name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isWaiting ? TPColor.textTertiary : TPColor.textPrimary)

            Spacer()
            scoreLabel
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var isWaiting: Bool { score == nil }

    private var rankLabel: some View {
        Text(rank.map(String.init) ?? "–")
            .font(TPFont.mono(12, weight: .bold))
            .foregroundStyle(rank == 1 ? TPColor.deceitText : TPColor.textSecondary)
            .frame(width: 20, alignment: .center)
    }

    @ViewBuilder
    private var scoreLabel: some View {
        if let score {
            Text(String(score))
                .font(TPFont.score(15))
                .tracking(-0.4)
                .foregroundStyle(Verdict(score: score).textColor)
        } else {
            Text("未")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TPColor.textTertiary)
        }
    }

    private var a11yLabel: String {
        guard let score else { return name + "、未計測" }
        let rankText = rank.map { String($0) + "位、" } ?? ""
        return rankText + name + "、誠実度 " + String(score) + " パーセント"
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        TPColor.backdrop
        VStack(spacing: 0) {
            GokonRankedRow(rank: 1, name: "ミク", score: 28)
            GokonRankedRow(rank: 2, name: "ユウキ", score: 61)
            GokonRankedRow(rank: nil, name: "ケンタ", score: nil)
        }
        .padding(.horizontal, 14)
        .background { GlassBackground() }
        .padding()
    }
    .preferredColorScheme(.dark)
}
