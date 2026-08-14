//
//  GokonTurnView.swift
//  TruthPulse
//
//  画面C: 出番の外枠。お題選び → 計測 → 解析まで。
//  計測パートはソロと同じ部品（TouchSensorPad 等）をそのまま再利用する。
//

import SwiftUI

@MainActor
struct GokonTurnView: View {

    let viewModel: GokonSessionViewModel
    let phase: GokonSessionViewModel.TurnPhase
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TPColor.backdrop
            ScrollView {
                VStack(spacing: TPMetrics.grid * 2) {
                    turnBanner
                    contextualSection
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
            Text(viewModel.progressText)
                .font(TPFont.mono(13))
                .foregroundStyle(TPColor.textTertiary)
            Spacer()
            TPPill(kind: .live, text: "進行中", showsPulsingDot: true)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    private var turnBanner: some View {
        VStack(spacing: 4) {
            Text("次の出番").tpLabelStyle(size: 10)
            Text(viewModel.currentPlayerDisplayName)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(TPColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Phase-dependent section

    @ViewBuilder
    private var contextualSection: some View {
        switch phase {
        case .pickingQuestion:
            GokonQuestionPickerView(viewModel: viewModel)
        case .awaitingTouch, .sampling, .interrupted, .analyzing:
            measuringSection
        }
    }

    private var measuringSection: some View {
        VStack(spacing: TPMetrics.grid * 1.5) {
            questionBanner
            ScoreRingView(
                score: viewModel.liveScore,
                progress: phase == .awaitingTouch ? 0 : viewModel.progress,
                heartbeatTick: viewModel.heartbeatTick,
                caption: viewModel.currentPlayerDisplayName
            )
            WaveformView(samples: viewModel.waveform, isLive: phase.isMeasuring)
            BioMetricsRow(pulse: viewModel.pulse, microTremor: viewModel.microTremor, stress: viewModel.stress)
            TouchSensorPad(
                state: padState,
                counterText: viewModel.samplingCounterText,
                onFingerDown: { viewModel.fingerDown() },
                onFingerMoved: { viewModel.fingerMoved(translation: $0) },
                onFingerUp: { viewModel.fingerUp() }
            )
        }
        .transition(.opacity)
    }

    private var questionBanner: some View {
        Text("「" + viewModel.question + "」")
            .font(TPFont.body(14))
            .foregroundStyle(TPColor.textPrimary)
            .multilineTextAlignment(.center)
            .tpLineSpacing(14)
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 16, padding: 14)
    }

    private var padState: TouchSensorPad.SensorState {
        switch phase {
        case .sampling: .reading
        case .interrupted: .interrupted
        case .analyzing: .analyzing
        default: .awaiting
        }
    }
}
