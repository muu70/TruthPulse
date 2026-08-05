//
//  ResultView.swift
//  TruthPulse
//
//  判定結果の詳細画面（モックアップ 04）。
//  計測直後だけでなく、履歴からも同じ画面を開けるよう ScanSession を受け取ります。
//

import SwiftUI
import SwiftData

@MainActor
struct ResultView: View {

    let session: ScanSession
    /// 「もう一問」。nil の場合はボタンを出さない（履歴から開いたとき）。
    var onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shareImage: Image?
    @State private var revealScore = false

    var body: some View {
        ZStack {
            TPColor.backdrop
            verdictGlow

            ScrollView {
                VStack(spacing: TPMetrics.grid * 1.75) {
                    verdictCard
                    breakdownCard
                    metaCard
                    actionButtons
                }
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.top, TPMetrics.grid)
                .padding(.bottom, TPMetrics.screenPadding * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        }
        .preferredColorScheme(.dark)
        .task {
            shareImage = ShareCardRenderer.render(session)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.15)) {
                revealScore = true
            }
        }
    }

    // MARK: - Chrome

    private var verdictGlow: some View {
        RadialGradient(
            colors: [session.verdict.accentColor.opacity(0.22), .clear],
            center: UnitPoint(x: 0.5, y: 0.12),
            startRadius: 0, endRadius: 420
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TPColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background { GlassBackground(cornerRadius: 12) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")

            Spacer()

            Text("判定結果")
                .font(TPFont.title())
                .foregroundStyle(TPColor.textPrimary)

            Spacer()

            if let shareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview(shareTitle, image: shareImage)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TPColor.cyan)
                        .frame(width: 34, height: 34)
                        .background { GlassBackground(cornerRadius: 12) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("結果を共有")
            } else {
                Color.clear.frame(width: 34, height: 34)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    // MARK: - Verdict

    private var verdictCard: some View {
        VStack(spacing: 0) {
            UsomiView(score: session.honestyScore, unit: 66)
                .padding(.bottom, 2)

            Text(session.headline)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.9)
                .multilineTextAlignment(.center)
                .foregroundStyle(session.verdict.textColor)
                .tpLineSpacing(30)
                .padding(.top, 4)

            if !session.question.isEmpty {
                Text(questionLine)
                    .font(TPFont.body(14))
                    .foregroundStyle(TPColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .tpLineSpacing(14)
                    .padding(.top, 14)
                    .padding(.horizontal, 8)
            }

            Text(session.comment)
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textSecondary)
                .multilineTextAlignment(.center)
                .tpLineSpacing(13)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            // 大きなスコア表示
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(session.honestyScore))
                    .font(TPFont.score(44))
                    .tracking(-2)
                    .foregroundStyle(TPColor.textPrimary)
                    .contentTransition(.numericText())
                Text("／ 100")
                    .font(TPFont.mono(13))
                    .foregroundStyle(TPColor.textTertiary)
            }
            .padding(.top, 18)
            .opacity(revealScore ? 1 : 0)
            .scaleEffect(revealScore ? 1 : 0.85)

            Text(confidenceLine)
                .font(TPFont.mono(11))
                .tracking(1.5)
                .foregroundStyle(TPColor.textTertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.verdict.voiceOverLabel)
        .accessibilityValue(scoreA11yValue)
    }

    private var shareTitle: String {
        "TruthPulse " + VerdictText.inlineHeadline(for: session.honestyScore)
    }

    /// 例: "Confidence 87% · Sample 8.0s"
    private var confidenceLine: String {
        let confidence: Int = session.confidence
        let duration: String = String(format: "%.1f", session.duration)
        return "確信度 " + String(confidence) + "% ・ 計測 " + duration + "秒"
    }

    private var questionLine: String {
        "「" + session.question + "」"
    }

    private var scoreA11yValue: String {
        let score: Int = session.honestyScore
        let confidence: Int = session.confidence
        return "質問、" + session.question
            + "。誠実度 " + String(score) + " パーセント、確信度 "
            + String(confidence) + " パーセント"
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("反応の内訳")
                    .tpLabelStyle()
                Spacer()
                Text("4項目")
                    .font(TPFont.mono(10))
                    .foregroundStyle(TPColor.textTertiary)
            }

            ForEach(session.factors.indices, id: \.self) { index in
                FactorBarRow(
                    factor: session.factors[index],
                    verdict: session.verdict,
                    revealDelay: 0.25 + Double(index) * 0.12
                )
            }
        }
        .glassCard(padding: 18)
    }

    // MARK: - Meta

    private var metaCard: some View {
        VStack(spacing: 0) {
            metaRow(icon: "clock", title: "計測時刻",
                    value: session.startedAt.formatted(date: .omitted, time: .shortened))
            divider
            metaRow(icon: "waveform.path.ecg", title: "モード", value: session.mode.displayName)
        }
        .padding(.horizontal, 16)
        .background { GlassBackground() }
    }

    private func metaRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(TPColor.textTertiary)
                .frame(width: 18)
            Text(title)
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TPColor.textPrimary)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if let shareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview(shareTitle, image: shareImage)
                ) {
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

            if let onRetry {
                TPButton(title: "もう一問", systemImage: "arrow.clockwise") {
                    onRetry()
                    dismiss()
                }
            }
        }
    }

}

// MARK: - Previews

#Preview("Deceptive") {
    ResultView(session: ScanSession.mocks[0], onRetry: {})
        .modelContainer(TPModelContainer.preview)
}

#Preview("Truthful") {
    ResultView(session: ScanSession.mocks[1], onRetry: {})
        .modelContainer(TPModelContainer.preview)
}

#Preview("履歴から · AX3") {
    ResultView(session: ScanSession.mocks[2])
        .modelContainer(TPModelContainer.preview)
        .environment(\.dynamicTypeSize, .accessibility3)
}
