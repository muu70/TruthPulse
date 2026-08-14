//
//  GokonFinalRankingView.swift
//  TruthPulse
//
//  画面E: 今夜いちばんの嘘つきランキング発表。
//  ここが一番の山場。シェア画像はこの画面専用の別レイアウトで作る
//  （ShareCardView は流用しない — BACKLOG.md の受け入れ条件）。
//

import SwiftUI

@MainActor
struct GokonFinalRankingView: View {

    let viewModel: GokonSessionViewModel
    let onClose: () -> Void

    @State private var shareImage: Image?

    var body: some View {
        ZStack {
            TPColor.backdrop
            ScrollView {
                VStack(spacing: TPMetrics.grid * 1.75) {
                    winnerCard
                    rankingCard
                    actionButtons
                }
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.bottom, TPMetrics.screenPadding * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        }
        .preferredColorScheme(.dark)
        .task {
            shareImage = RankingShareCardRenderer.render(shareData)
        }
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
            .accessibilityLabel("閉じる")

            Spacer()
            Text("結果発表").font(TPFont.title()).foregroundStyle(TPColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    // MARK: - Winner

    private var winnerCard: some View {
        VStack(spacing: 8) {
            Text("今夜いちばんの嘘つき")
                .font(TPFont.mono(11))
                .tracking(1.5)
                .foregroundStyle(TPColor.caution)

            if let winner = viewModel.rankedResults.first {
                UsomiView(score: winner.honestyScore, unit: 60)
                Text(winner.playerName)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(TPColor.deceitText)
                Text("平均 " + String(winner.honestyScore) + "点")
                    .font(TPFont.mono(12))
                    .foregroundStyle(TPColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ranking

    private var rankingCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.rankedResults.enumerated()), id: \.element.id) { index, result in
                GokonRankedRow(rank: index + 1, name: result.playerName, score: result.honestyScore)
                if index < viewModel.rankedResults.count - 1 { rowDivider }
            }
        }
        .padding(.horizontal, 14)
        .background { GlassBackground() }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if let shareImage {
                shareButton(shareImage)
            }
            TPButton(title: "罰ゲーム", systemImage: "gift.fill") {
                viewModel.startPenaltyRoulette()
            }
        }
    }

    private func shareButton(_ image: Image) -> some View {
        ShareLink(item: image, preview: SharePreview("今夜の結果", image: image)) {
            HStack(spacing: 9) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text("シェア")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(TPColor.textPrimary)
            .background { GlassBackground(cornerRadius: TPMetrics.buttonRadius) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share data

    private var shareData: RankingShareCardData {
        let entries = viewModel.rankedResults.enumerated().map { index, result in
            RankingShareCardData.Entry(rank: index + 1, name: result.playerName, score: result.honestyScore)
        }
        return RankingShareCardData(groupID: viewModel.groupID ?? UUID(), date: .now, entries: entries)
    }
}
