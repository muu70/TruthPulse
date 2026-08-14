//
//  GokonLeaderboardView.swift
//  TruthPulse
//
//  画面D: 直前の結果 + 途中経過。まだ計測していない人に「次は自分」を
//  意識させ、待っている人が焦るのがこの画面の役割。
//

import SwiftUI

@MainActor
struct GokonLeaderboardView: View {

    let viewModel: GokonSessionViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TPColor.backdrop
            ScrollView {
                VStack(spacing: TPMetrics.grid * 1.75) {
                    if let result = viewModel.lastResult {
                        resultCard(result)
                    }
                    rankingList
                    nextButton
                }
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.bottom, TPMetrics.screenPadding * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var navigationBar: some View {
        HStack {
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TPColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background { GlassBackground(cornerRadius: 12) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("合コンモードを終了")

            Spacer()
            Text("判定").font(TPFont.title()).foregroundStyle(TPColor.textPrimary)
            Spacer()
            TPPill(kind: .ok, text: progressBadge)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    private var progressBadge: String {
        String(viewModel.results.count) + " / " + String(viewModel.players.count)
    }

    // MARK: - Result card

    private func resultCard(_ result: GokonTurnResult) -> some View {
        VStack(spacing: 8) {
            Image(systemName: result.verdict.symbolName)
                .font(.system(size: 26))
                .foregroundStyle(result.verdict.textColor)
            Text(result.playerName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TPColor.textSecondary)
            Text(VerdictText.inlineHeadline(for: result.honestyScore))
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(result.verdict.textColor)
            Text("「" + result.question + "」")
                .font(TPFont.body(12.5))
                .foregroundStyle(TPColor.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(String(result.honestyScore))
                .font(TPFont.score(38))
                .foregroundStyle(TPColor.textPrimary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ranking

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在の順位").tpLabelStyle(size: 10)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GokonRankedRow(rank: row.rank, name: row.name, score: row.score)
                    if index < rows.count - 1 { rowDivider }
                }
            }
            .padding(.horizontal, 14)
            .background { GlassBackground() }
        }
    }

    private struct Row { let rank: Int?; let name: String; let score: Int? }

    /// 判定済みの人を上位から、未計測の人をその下に並べた1本のリスト。
    private var rows: [Row] {
        let ranked = viewModel.rankedResults.enumerated().map { index, result in
            Row(rank: index + 1, name: result.playerName, score: result.honestyScore)
        }
        let waitingIndices = viewModel.players.indices.filter { index in
            !viewModel.results.contains { $0.playerIndex == index }
        }
        let waiting = waitingIndices.map { index in
            Row(rank: nil, name: viewModel.players[index].displayName(at: index), score: nil)
        }
        return ranked + waiting
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    // MARK: - Next

    private var nextButton: some View {
        TPButton(
            title: viewModel.isLastPlayer ? "最終結果を見る" : "次は" + nextPlayerName + "さん",
            systemImage: viewModel.isLastPlayer ? "trophy.fill" : "arrow.right"
        ) {
            viewModel.advanceToNextPlayer()
        }
    }

    private var nextPlayerName: String {
        let nextIndex = viewModel.currentPlayerIndex + 1
        guard viewModel.players.indices.contains(nextIndex) else { return "" }
        return viewModel.players[nextIndex].displayName(at: nextIndex)
    }
}
