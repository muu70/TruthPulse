//
//  SoloSessionView.swift
//  TruthPulse
//
//  ソロ・セッション（メイン計測画面）。
//  モックアップ 02 に対応します。
//

import SwiftUI
import SwiftData

@MainActor
struct SoloSessionView: View {

    @State private var viewModel = SoloSessionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var questionFieldFocused: Bool
    /// 保存済みセッション。結果画面を閉じたあとも保持し、再表示できるようにする。
    @State private var completedSession: ScanSession?
    @State private var isShowingResult = false

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .onChange(of: viewModel.phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }
            .fullScreenCover(isPresented: $isShowingResult) { resultCover }
            .animation(reduceMotion ? .none : .snappy(duration: 0.35), value: viewModel.phase)
    }

    private var content: some View {
        ZStack {
            TPColor.backdrop
            DataGridOverlay()

            VStack(spacing: 0) {
                navigationBar
                    .padding(.horizontal, TPMetrics.screenPadding)
                    .padding(.bottom, TPMetrics.grid * 2.5)

                scrollBody
            }
            .safeAreaPadding(.top, 4)
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: TPMetrics.grid * 2) {
                scoreRing
                waveform
                BioMetricsRow(
                    pulse: viewModel.pulse,
                    microTremor: viewModel.microTremor,
                    stress: viewModel.stress
                )
                contextualSection
            }
            .padding(.horizontal, TPMetrics.screenPadding)
            .padding(.bottom, TPMetrics.screenPadding * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var scoreRing: some View {
        let progress: Double = viewModel.phase == .idle ? 0 : viewModel.progress

        return ScoreRingView(
            score: viewModel.displayedScore,
            progress: progress,
            heartbeatTick: viewModel.heartbeatTick,
            accent: viewModel.result?.verdict.accentColor
        )
        .padding(.top, TPMetrics.grid)
    }

    private var waveform: some View {
        let color: Color = viewModel.result?.verdict.accentColor ?? TPColor.cyan

        return WaveformView(
            samples: viewModel.waveform,
            color: color,
            isLive: viewModel.phase.isMeasuring
        )
    }

    @ViewBuilder
    private var resultCover: some View {
        if let completedSession {
            ResultView(session: completedSession) {
                viewModel.resetToIdle()
            }
        }
    }

    private func handlePhaseChange(_ newPhase: SoloSessionViewModel.Phase) {
        switch newPhase {
        case .result:
            completedSession = viewModel.persist(in: modelContext)
            isShowingResult = completedSession != nil
        case .idle:
            completedSession = nil
        default:
            break
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack {
            Button {
                viewModel.resetToIdle()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TPColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background { GlassBackground(cornerRadius: 12) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            Text("ソロ・スキャン")
                .font(TPFont.title())
                .foregroundStyle(TPColor.textPrimary)

            Spacer()

            statusPill
                .frame(minWidth: 34, alignment: .trailing)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch viewModel.phase {
        case .sampling:
            TPPill(kind: .live, text: "計測中", showsPulsingDot: true)
        case .interrupted:
            TPPill(kind: .neutral, text: "一時停止")
        case .analyzing:
            TPPill(kind: .neutral, text: "解析中", showsPulsingDot: true)
        case .result:
            TPPill(kind: viewModel.result?.verdict == .truthful ? .ok : .live,
                   text: "完了")
        default:
            Color.clear.frame(width: 1, height: 1)
        }
    }

    // MARK: - Phase-dependent section

    @ViewBuilder
    private var contextualSection: some View {
        switch viewModel.phase {
        case .idle:
            questionEntry
                .transition(.opacity.combined(with: .move(edge: .bottom)))

        case .awaitingTouch, .sampling, .interrupted, .analyzing:
            VStack(spacing: TPMetrics.grid * 1.5) {
                if !viewModel.question.isEmpty {
                    questionBanner
                }
                TouchSensorPad(
                    state: padState,
                    counterText: viewModel.samplingCounterText,
                    onFingerDown: { viewModel.fingerDown() },
                    onFingerMoved: { viewModel.fingerMoved(translation: $0) },
                    onFingerUp: { viewModel.fingerUp() }
                )
                if viewModel.phase == .awaitingTouch {
                    Button("質問を編集") { viewModel.resetToIdle() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TPColor.textTertiary)
                }
            }
            .transition(.opacity)

        case .result:
            resultSummary
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var padState: TouchSensorPad.SensorState {
        switch viewModel.phase {
        case .sampling: .reading
        case .interrupted: .interrupted
        case .analyzing: .analyzing
        default: .awaiting
        }
    }

    // MARK: - Idle: question entry

    private var questionEntry: some View {
        VStack(alignment: .leading, spacing: TPMetrics.grid * 1.5) {
            VStack(alignment: .leading, spacing: 4) {
                Text("質問（任意）")
                    .tpLabelStyle()
                Text("空のままでも計測できます")
                    .font(.system(size: 11))
                    .foregroundStyle(TPColor.textTertiary)
            }

            TextField("例: 元カノのことは忘れた", text: $viewModel.question, axis: .vertical)
                .font(TPFont.body(15))
                .foregroundStyle(TPColor.textPrimary)
                .tint(TPColor.cyan)
                .lineLimit(1...3)
                .focused($questionFieldFocused)
                .submitLabel(.done)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background { GlassBackground(cornerRadius: 16) }
                .accessibilityLabel("質問を入力、任意")

            TPButton(title: "スキャンを開始", systemImage: "play.fill") {
                questionFieldFocused = false
                viewModel.beginSession()
            }
            .opacity(viewModel.canStart ? 1 : 0.4)
            .disabled(!viewModel.canStart)
            .padding(.top, TPMetrics.grid / 2)

        }
        .glassCard(padding: 18)
    }

    private var questionBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("質問")
                .tpLabelStyle(size: 10)
            Text("「" + viewModel.question + "」")
                .font(TPFont.body(14))
                .foregroundStyle(TPColor.textPrimary)
                .tpLineSpacing(14)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16, padding: 14)
    }

    // MARK: - Result

    /// 詳細はフルスクリーンの `ResultView` が担当。
    /// ここは結果画面を閉じたあとに残る「戻り口」。
    @ViewBuilder
    private var resultSummary: some View {
        if let result = viewModel.result, completedSession != nil {
            VStack(spacing: TPMetrics.grid * 1.5) {
                reopenButton(result: result)
                resultActions
            }
        }
    }

    private func reopenButton(result: SoloSessionViewModel.SessionResult) -> some View {
        let verdict: Verdict = result.verdict
        let headline: String = VerdictText.inlineHeadline(for: result.score)
        let sub: String = "確信度 " + String(result.confidence) + "% ・ タップで詳細"
        let a11y: String = verdict.voiceOverLabel + "。誠実度 " + String(result.score) + " パーセント"

        return Button {
            isShowingResult = true
        } label: {
            reopenLabel(verdict: verdict, headline: headline, sub: sub)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
        .accessibilityHint("ダブルタップで詳細を表示")
    }

    private func reopenLabel(verdict: Verdict, headline: String, sub: String) -> some View {
        HStack(spacing: 14) {
            verdictIcon(verdict)

            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(verdict.textColor)
                Text(sub)
                    .font(TPFont.mono(10))
                    .foregroundStyle(TPColor.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TPColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 16)
    }

    private func verdictIcon(_ verdict: Verdict) -> some View {
        let fill: Color = verdict.accentColor.opacity(0.18)
        let stroke: Color = verdict.accentColor.opacity(0.55)

        return Image(systemName: verdict.symbolName)
            .font(.system(size: 20))
            .foregroundStyle(verdict.textColor)
            .frame(width: 46, height: 46)
            .background {
                Circle().fill(fill)
                Circle().strokeBorder(stroke, lineWidth: 1)
            }
    }

    private var resultActions: some View {
        HStack(spacing: 10) {
            TPButton(title: "終了", systemImage: "checkmark", style: .ghost) {
                viewModel.resetToIdle()
                dismiss()
            }
            TPButton(title: "もう一問", systemImage: "arrow.clockwise") {
                viewModel.resetToIdle()
            }
        }
    }

}

// MARK: - Background grid

/// 背景の 26pt データグリッド。Reduce Transparency 時は非表示。
private struct DataGridOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if !reduceTransparency {
            Canvas { context, size in
                let spacing: CGFloat = 26
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(TPColor.cyan.opacity(0.045)), lineWidth: 1)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews

#Preview("Solo Session") {
    SoloSessionView()
        .modelContainer(TPModelContainer.preview)
}

// Reduce Motion / Reduce Transparency は読み取り専用の Environment キーのため
// プレビューから注入できません。確認は シミュレータ → 設定 → アクセシビリティ →
// 動作 →「視差効果を減らす」から行ってください。
#Preview("Accessibility · AX3") {
    SoloSessionView()
        .modelContainer(TPModelContainer.preview)
        .environment(\.dynamicTypeSize, .accessibility3)
}
