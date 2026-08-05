//
//  ModeSelectView.swift
//  TruthPulse
//
//  エントリー画面（モックアップ 01）。
//  「最初の 3 秒で本物っぽい機械だと思わせる」ことだけを担当します。
//

import SwiftUI
import SwiftData

/// アプリ全体の遷移先。
enum TPRoute: Hashable {
    case soloSession
    case duoSession
    case history
}

@MainActor
struct ModeSelectView: View {

    @Query(sort: \ScanSession.startedAt, order: .reverse)
    private var sessions: [ScanSession]

    @Binding var path: [TPRoute]

    @State private var selectedMode: ScanMode = .solo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 初回だけ案内を出す。2 回目以降は「本物の機械っぽさ」を優先して出さない。
    @AppStorage("tp.hasSeenWelcome") private var hasSeenWelcome = false
    @State private var isShowingWelcome = false

    var body: some View {
        ZStack {
            TPColor.backdrop

            ScrollView {
                VStack(spacing: 0) {
                    SoundSettingsBar()
                        .padding(.top, 6)

                    brandmark
                        .padding(.top, typeSize.isAccessibilitySize ? 4 : 10)
                        .padding(.bottom, 26)

                    modeCards

                    TPButton(title: startButtonTitle, systemImage: startButtonIcon) {
                        path.append(selectedMode == .solo ? .soloSession : .duoSession)
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.bottom, TPMetrics.screenPadding * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .preferredColorScheme(.dark)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onChange(of: selectedMode) { _, _ in
            TPHaptics.select()
            TPAudio.shared.play(.select, volume: 0.6)
        }
        .task {
            if !hasSeenWelcome { isShowingWelcome = true }
        }
        .fullScreenCover(isPresented: $isShowingWelcome) {
            WelcomeSheet {
                hasSeenWelcome = true
                isShowingWelcome = false
            }
        }
    }

    // MARK: - Brandmark

    private var brandmark: some View {
        VStack(spacing: 0) {
            PulseLogo()
                .padding(.bottom, 16)

            Text("TruthPulse")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(TPColor.textPrimary)

            Text("Bio-Signal Analyzer")
                .tpLabelStyle(size: 12)
                .padding(.top, 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TruthPulse、生体信号アナライザー")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Cards

    private var modeCards: some View {
        VStack(spacing: 14) {
            ModeCard(
                icon: "person.fill",
                title: ScanMode.solo.displayName,
                subtitle: "1人で計測。指を置いて反応を読み取ります",
                palette: .solo,
                isSelected: selectedMode == .solo
            ) {
                selectedMode = .solo
            }

            ModeCard(
                icon: "person.2.fill",
                title: ScanMode.duo.displayName,
                subtitle: "2人で顔を寄せて計測します",
                palette: .duo,
                isSelected: selectedMode == .duo
            ) {
                selectedMode = .duo
            }

            ModeCard(
                icon: "list.bullet.rectangle",
                title: "セッション履歴",
                subtitle: historySubtitle,
                palette: .neutral,
                isEnabled: !sessions.isEmpty
            ) {
                path.append(.history)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selectedMode)
    }

    private var startButtonTitle: String {
        selectedMode == .solo ? "スキャンを開始" : "2人でスキャン"
    }

    private var startButtonIcon: String {
        selectedMode == .solo ? "play.fill" : "camera.fill"
    }

    private var historySubtitle: String {
        guard !sessions.isEmpty else { return "まだ記録がありません" }

        let todayCount = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }.count
        return todayCount > 0
            ? "今夜のスコア \(todayCount)件"
            : "過去の記録 \(sessions.count)件"
    }

}

// MARK: - Previews

#Preview("履歴あり") {
    @Previewable @State var path: [TPRoute] = []

    NavigationStack(path: $path) {
        ModeSelectView(path: $path)
    }
    .modelContainer(TPModelContainer.preview)
}

#Preview("初回起動 · AX3") {
    @Previewable @State var path: [TPRoute] = []

    NavigationStack(path: $path) {
        ModeSelectView(path: $path)
    }
    .modelContainer(for: [ScanSession.self, BioSample.self], inMemory: true)
    .environment(\.dynamicTypeSize, .accessibility3)
}
