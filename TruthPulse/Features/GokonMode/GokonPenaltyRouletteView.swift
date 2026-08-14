//
//  GokonPenaltyRouletteView.swift
//  TruthPulse
//
//  画面F: 罰ゲームルーレット。飲酒を強いる罰ゲームは
//  GokonPenaltyDeck に一切含めていない（BACKLOG.md の制約）。
//

import SwiftUI

@MainActor
struct GokonPenaltyRouletteView: View {

    let viewModel: GokonSessionViewModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wheelRotation: Angle = .zero
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            TPColor.backdrop
            VStack(spacing: TPMetrics.grid * 2) {
                spinnerHint
                wheel
                penaltyResult
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, TPMetrics.screenPadding)
            .padding(.bottom, TPMetrics.screenPadding * 2)
            .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var navigationBar: some View {
        HStack {
            Color.clear.frame(width: 34, height: 34)
            Spacer()
            Text("罰ゲーム").font(TPFont.title()).foregroundStyle(TPColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    @ViewBuilder
    private var spinnerHint: some View {
        if let winner = viewModel.rankedResults.first {
            TPPill(kind: .live, text: winner.playerName + "さんが回します")
        }
    }

    // MARK: - Wheel

    private var wheel: some View {
        GokonRouletteWheel(sliceCount: GokonPenaltyDeck.all.count, rotation: wheelRotation)
            .frame(width: 220, height: 220)
            .overlay(alignment: .top) { needle }
            .onTapGesture { spin() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ルーレット")
            .accessibilityValue(viewModel.currentPenalty?.text ?? "未回転")
            .accessibilityHint("ダブルタップで回します")
            .accessibilityAddTraits(.isButton)
    }

    private var needle: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 18))
            .foregroundStyle(TPColor.caution)
            .offset(y: -6)
            .accessibilityHidden(true)
    }

    // MARK: - Result

    @ViewBuilder
    private var penaltyResult: some View {
        if let penalty = viewModel.currentPenalty {
            VStack(spacing: 6) {
                Text("出た罰ゲーム").tpLabelStyle(size: 10)
                Text(penalty.text)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TPColor.caution)
                    .tpLineSpacing(20)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
        } else {
            Text("円盤をタップして回してください")
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textTertiary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 9) {
            TPButton(title: "もう一回まわす", systemImage: "arrow.clockwise") { spin() }
            Button("終わる") {
                viewModel.restart()
                onClose()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(TPColor.textTertiary)
        }
    }

    // MARK: - Spin

    private func spin() {
        guard !isSpinning else { return }
        let penalty = viewModel.spinPenalty()
        TPHaptics.select()

        guard !reduceMotion else {
            wheelRotation = Angle(degrees: -landingOffsetDegrees(for: penalty))
            return
        }

        isSpinning = true
        let extraSpins = Double.random(in: 4...6) * 360
        let targetDegrees = wheelRotation.degrees - extraSpins - landingOffsetDegrees(for: penalty)
        withAnimation(.easeOut(duration: 2.2)) {
            wheelRotation = Angle(degrees: targetDegrees)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(2_200))
            isSpinning = false
            TPHaptics.success()
        }
    }

    /// 針（円盤上部）の位置にちょうど選ばれた区画が来るための回転量。
    private func landingOffsetDegrees(for penalty: GokonPenalty) -> Double {
        guard let targetIndex = GokonPenaltyDeck.all.firstIndex(where: { $0.id == penalty.id }) else {
            return 0
        }
        let sliceAngle = 360.0 / Double(GokonPenaltyDeck.all.count)
        return sliceAngle * Double(targetIndex) + sliceAngle / 2
    }
}
