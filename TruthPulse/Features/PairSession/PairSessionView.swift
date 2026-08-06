//
//  PairSessionView.swift
//  TruthPulse
//
//  ペア判定。2 人が 1 本ずつ指を置き、近づけながら耐えます。
//
//  NOTE: 型チェックを軽く保つため body は最小にし、
//        計算は明示的な型注釈つきのメソッドへ逃がしています。
//

import SwiftUI
import SwiftData

@MainActor
struct PairSessionView: View {

    @State private var viewModel = PairSessionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var questionFocused: Bool

    @State private var completedSession: ScanSession?

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) { closeButton }
            .onChange(of: viewModel.phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }
            .onChange(of: completedSession) { _, session in
                handleResultDismissed(session)
            }
            .fullScreenCover(item: $completedSession) { session in
                ResultView(session: session, onRetry: {})
            }
            .onDisappear { viewModel.stopEverything() }
    }

    private var content: some View {
        ZStack {
            TPColor.backdrop

            if viewModel.phase == .setup {
                setupSheet
            } else {
                measuringLayer
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: viewModel.phase)
    }

    private func handlePhaseChange(_ newPhase: PairSessionViewModel.Phase) {
        guard newPhase == .result else { return }
        completedSession = viewModel.persist(in: modelContext)
    }

    /// 結果を閉じたら、同じ質問のまま次の 2 人へ。
    private func handleResultDismissed(_ session: ScanSession?) {
        guard session == nil, viewModel.phase == .result else { return }
        viewModel.restart()
    }

    // MARK: - Measuring

    private var measuringLayer: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.top, 6)

            touchPad
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.top, 10)

            guidanceBlock
                .padding(.top, 16)

            progressBar
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
    }

    private var statusBar: some View {
        HStack {
            Color.clear.frame(width: 34, height: 34)
            Spacer()
            Text("ペア・スキャン")
                .font(TPFont.title(17))
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
        case .awaiting:
            TPPill(kind: .neutral, text: touchCountText, showsPulsingDot: true)
        case .measuring:
            TPPill(kind: .live, text: "計測中", showsPulsingDot: true)
        case .interrupted:
            TPPill(kind: .live, text: "指が離れました")
        case .analyzing:
            TPPill(kind: .neutral, text: "解析中", showsPulsingDot: true)
        default:
            EmptyView()
        }
    }

    private var touchCountText: String {
        "指 " + String(viewModel.touches.count) + "/2"
    }

    /// パッド本体。中で MultiTouchPad が座標を拾い、上に発光を重ねる。
    private var touchPad: some View {
        GeometryReader { proxy in
            ZStack {
                padBackground
                MultiTouchPad { points in
                    viewModel.updateTouches(points)
                }
                FingerLinkOverlay(
                    points: viewModel.touches,
                    closeness: viewModel.closeness,
                    isMeasuring: viewModel.phase == .measuring
                )
                if viewModel.touches.isEmpty {
                    emptyHint
                }
            }
            .onAppear { viewModel.updatePadWidth(proxy.size.width) }
            .onChange(of: proxy.size) { _, size in
                viewModel.updatePadWidth(size.width)
            }
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ペア用センサー")
        .accessibilityValue(viewModel.guidance.title)
    }

    private var padBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let border: Color = viewModel.isContacting
            ? TPColor.truth.opacity(0.7)
            : TPColor.cyan.opacity(0.35)

        return ZStack {
            shape.fill(
                RadialGradient(
                    colors: [TPColor.cyan.opacity(0.10), TPColor.purple.opacity(0.08), .clear],
                    center: .center, startRadius: 10, endRadius: 320
                )
            )
            shape.strokeBorder(border, style: StrokeStyle(lineWidth: 1.5, dash: [8, 7]))
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 26))
                .foregroundStyle(TPColor.cyan.opacity(0.6))
            Text("2人とも、ここに指を1本ずつ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TPColor.cyan)
        }
    }

    private var guidanceBlock: some View {
        let guidance = viewModel.guidance

        return VStack(spacing: 5) {
            Text(guidance.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TPColor.textPrimary)
            Text(guidance.detail)
                .font(TPFont.body(12.5))
                .foregroundStyle(TPColor.textSecondary)
                .tpLineSpacing(12.5)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, TPMetrics.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            progressFill(width: proxy.size.width)
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("計測の進捗")
        .accessibilityValue(progressA11yValue)
    }

    private var progressA11yValue: String {
        let percent: Int = Int(viewModel.progress * 100)
        return String(percent) + " パーセント"
    }

    private func progressFill(width: CGFloat) -> some View {
        let filled: CGFloat = max(0, width * CGFloat(viewModel.progress))

        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [TPColor.deceit, TPColor.cyan],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: filled)
        }
    }

    // MARK: - Setup

    private var setupSheet: some View {
        VStack {
            Spacer()
            setupCard
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.bottom, 40)
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: TPMetrics.grid * 1.5) {
            setupHeader

            Text("2人で指を1本ずつ置き、近づけながら8秒。\n離れているほど反応が乱れます。")
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textSecondary)
                .tpLineSpacing(13)

            questionField
            startButton

            Text("抵抗がある人がいるときは、無理に触れなくても計測できます。")
                .font(.system(size: 11))
                .foregroundStyle(TPColor.textTertiary)
                .tpLineSpacing(11)
        }
        .glassCard(padding: 20)
    }

    private var setupHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 17))
                .foregroundStyle(TPColor.cyan)
            Text("ペア・スキャン")
                .font(TPFont.title(18))
                .foregroundStyle(TPColor.textPrimary)
        }
    }

    private var questionField: some View {
        TextField("質問（任意）　例: この中にタイプの人がいる", text: $viewModel.question, axis: .vertical)
            .font(TPFont.body(15))
            .foregroundStyle(TPColor.textPrimary)
            .tint(TPColor.cyan)
            .lineLimit(1...3)
            .focused($questionFocused)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background { GlassBackground(cornerRadius: 16) }
            .accessibilityLabel("質問を入力、任意")
    }

    private var startButton: some View {
        TPButton(title: "はじめる", systemImage: "play.fill") {
            questionFocused = false
            viewModel.begin()
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            viewModel.stopEverything()
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
        .padding(.leading, TPMetrics.screenPadding)
        .padding(.top, 6)
    }
}

#Preview {
    PairSessionView()
        .modelContainer(TPModelContainer.preview)
}
