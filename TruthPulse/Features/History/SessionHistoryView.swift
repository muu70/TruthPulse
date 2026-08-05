//
//  SessionHistoryView.swift
//  TruthPulse
//
//  セッション履歴の簡易リスト。
//  グラフ付きのフルダッシュボード（モックアップ 05）に置き換える予定の暫定版です。
//

import SwiftUI
import SwiftData

@MainActor
struct SessionHistoryView: View {

    @Query(sort: \ScanSession.startedAt, order: .reverse)
    private var sessions: [ScanSession]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: ScanSession?

    var body: some View {
        ZStack {
            TPColor.backdrop

            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: TPMetrics.grid * 1.5) {
                        summary
                        rows
                    }
                    .padding(.horizontal, TPMetrics.screenPadding)
                    .padding(.bottom, TPMetrics.screenPadding * 2)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        .preferredColorScheme(.dark)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedSession) { session in
            ResultView(session: session)
        }
    }

    // MARK: - Chrome

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TPColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background { GlassBackground(cornerRadius: 12) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            Text("これまでの記録")
                .font(TPFont.title())
                .foregroundStyle(TPColor.textPrimary)

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    // MARK: - Summary

    private var summary: some View {
        HStack(spacing: 10) {
            statTile(key: "平均誠実度", value: String(averageScore), tint: TPColor.cyan)
            statTile(key: "嘘の判定", value: String(deceptiveCount), tint: TPColor.deceitText)
        }
    }

    private func statTile(key: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(key).tpLabelStyle(size: 10)
            Text(value)
                .font(TPFont.score(26))
                .tracking(-0.8)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { GlassBackground(cornerRadius: 18) }
        .accessibilityElement(children: .combine)
    }

    private var averageScore: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.honestyScore } / sessions.count
    }

    private var deceptiveCount: Int {
        sessions.filter { $0.verdict == .deceptive }.count
    }

    // MARK: - Rows

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                Button { selectedSession = session } label: {
                    row(for: session)
                }
                .buttonStyle(.plain)

                if index < sessions.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .background { GlassBackground() }
    }

    private func row(for session: ScanSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.verdict.symbolName)
                .font(.system(size: 15))
                .foregroundStyle(session.verdict.textColor)
                .frame(width: 38, height: 38)
                .background {
                    let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
                    shape.fill(session.verdict.accentColor.opacity(0.18))
                    shape.strokeBorder(session.verdict.accentColor.opacity(0.45), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.inlineHeadline)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(session.verdict.textColor)
                Text(subtitle(for: session))
                    .font(.system(size: 11))
                    .foregroundStyle(TPColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(String(session.honestyScore))
                .font(TPFont.score(17))
                .tracking(-0.4)
                .foregroundStyle(session.verdict.textColor)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.inlineHeadline)
        .accessibilityValue(a11yValue(for: session))
        .accessibilityHint("ダブルタップで詳細を表示")
    }

    // Text の文字列補間は型チェックが重いため、String を先に組み立てる。
    private func subtitle(for session: ScanSession) -> String {
        let time: String = session.startedAt.formatted(date: .omitted, time: .shortened)
        if session.question.isEmpty {
            return session.mode.displayName + " ・ " + time
        }
        return "「" + session.question + "」 ・ " + time
    }

    private func a11yValue(for session: ScanSession) -> String {
        let score: Int = session.honestyScore
        return session.verdict.voiceOverLabel + "、誠実度 " + String(score) + " パーセント"
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 34))
                .foregroundStyle(TPColor.textTertiary)
            Text("まだ記録がありません")
                .font(TPFont.title(17))
                .foregroundStyle(TPColor.textPrimary)
            Text("スキャンを1回行うと、ここに残ります。")
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
    .modelContainer(TPModelContainer.preview)
}

#Preview("空の状態") {
    NavigationStack {
        SessionHistoryView()
    }
    .modelContainer(for: [ScanSession.self, BioSample.self], inMemory: true)
}
