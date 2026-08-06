//
//  SessionHistoryView.swift
//  TruthPulse
//
//  記録ダッシュボード。時間帯別の誠実度グラフとサマリー、記録一覧を表示します。
//

import SwiftUI
import SwiftData

@MainActor
struct SessionHistoryView: View {

    private enum Scope: CaseIterable, Hashable {
        case tonight, all

        var title: String {
            switch self {
            case .tonight: "今夜"
            case .all: "すべて"
            }
        }
    }

    @Query(sort: \ScanSession.startedAt, order: .reverse)
    private var sessions: [ScanSession]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: ScanSession?
    @State private var scope: Scope = .tonight

    var body: some View {
        ZStack {
            TPColor.backdrop

            if sessions.isEmpty {
                emptyState
            } else if filteredSessions.isEmpty {
                scopeEmptyState
            } else {
                content
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        .preferredColorScheme(.dark)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedSession) { session in
            ResultView(session: session)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: TPMetrics.grid * 1.5) {
                summary
                HonestyTimelineChart(buckets: hourlyBuckets)
                rows
            }
            .padding(.horizontal, TPMetrics.screenPadding)
            .padding(.bottom, TPMetrics.screenPadding * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
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

    // MARK: - Scope

    private var scopeToggle: some View {
        HStack(spacing: 4) {
            ForEach(Scope.allCases, id: \.self) { candidate in
                scopeChip(candidate)
            }
        }
        .padding(3)
        .background { GlassBackground(cornerRadius: 14) }
    }

    private func scopeChip(_ candidate: Scope) -> some View {
        let selected: Bool = candidate == scope

        return Button {
            scope = candidate
        } label: {
            Text(candidate.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: 0x00121F) : TPColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background {
                    if selected {
                        Capsule().fill(TPColor.brandGradient)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 10) {
            scopeToggle

            HStack(spacing: 10) {
                statTile(key: "平均誠実度", value: String(averageScore), tint: TPColor.cyan)
                statTile(key: "嘘の判定", value: String(deceptiveCount), tint: TPColor.deceitText)
                statTile(key: "計測回数", value: String(filteredSessions.count), tint: TPColor.truthText)
            }

            modeBreakdownRow
        }
    }

    private func statTile(key: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(key).tpLabelStyle(size: 9.5)
            Text(value)
                .font(TPFont.score(22))
                .tracking(-0.6)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background { GlassBackground(cornerRadius: 16) }
        .accessibilityElement(children: .combine)
    }

    private var modeBreakdownRow: some View {
        HStack(spacing: 8) {
            ForEach(ScanMode.allCases, id: \.rawValue) { mode in
                modeChip(mode)
            }
        }
    }

    private func modeChip(_ mode: ScanMode) -> some View {
        let count = filteredSessions.filter { $0.mode == mode }.count

        return HStack(spacing: 6) {
            Image(systemName: mode.symbolName)
                .font(.system(size: 11, weight: .semibold))
            Text(mode.shortDisplayName + " " + String(count))
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundStyle(TPColor.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background { GlassBackground(cornerRadius: 12) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mode.displayName)
        .accessibilityValue(String(count) + "回")
    }

    private var averageScore: Int {
        guard !filteredSessions.isEmpty else { return 0 }
        return filteredSessions.reduce(0) { $0 + $1.honestyScore } / filteredSessions.count
    }

    private var deceptiveCount: Int {
        filteredSessions.filter { $0.verdict == .deceptive }.count
    }

    // MARK: - Filtering / aggregation

    private var filteredSessions: [ScanSession] {
        switch scope {
        case .tonight: sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        case .all: sessions
        }
    }

    private var hourlyBuckets: [HonestyTimelineChart.Bucket] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSessions) { calendar.component(.hour, from: $0.startedAt) }
        return grouped.map { hour, group in
            let average = group.reduce(0) { $0 + $1.honestyScore } / group.count
            return HonestyTimelineChart.Bucket(hour: hour, averageScore: average, count: group.count)
        }
        .sorted { $0.hour < $1.hour }
    }

    // MARK: - Rows

    private var rows: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredSessions.enumerated()), id: \.element.id) { index, session in
                Button { selectedSession = session } label: {
                    row(for: session)
                }
                .buttonStyle(.plain)

                if index < filteredSessions.count - 1 {
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

    /// scope が「今夜」のときだけ到達する。「すべて」に記録があれば sessions は空でないため。
    private var scopeEmptyState: some View {
        VStack(spacing: 14) {
            scopeToggle
            VStack(spacing: 12) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 30))
                    .foregroundStyle(TPColor.textTertiary)
                Text("今夜はまだ記録がありません")
                    .font(TPFont.title(16))
                    .foregroundStyle(TPColor.textPrimary)
                Text("「すべて」に切り替えると、過去の記録を確認できます。")
                    .font(TPFont.body(12.5))
                    .foregroundStyle(TPColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .tpLineSpacing(12.5)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, TPMetrics.screenPadding)
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

#Preview("100件") {
    let schema = Schema([ScanSession.self, BioSample.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)

    for i in 0..<100 {
        let session = ScanSession(
            mode: ScanMode.allCases[i % 3],
            question: i % 4 == 0 ? "" : "質問 \(i)",
            honestyScore: (i * 37) % 100,
            confidence: 60,
            duration: 8,
            factors: []
        )
        session.startedAt = Calendar.current.date(
            byAdding: .hour, value: -i, to: .now
        ) ?? .now
        container.mainContext.insert(session)
    }

    return NavigationStack {
        SessionHistoryView()
    }
    .modelContainer(container)
}
