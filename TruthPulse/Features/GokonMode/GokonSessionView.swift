//
//  GokonSessionView.swift
//  TruthPulse
//
//  合コンモードのルート。stage に応じて各画面を出し分ける。
//  ソロ等と違い画面数が多いため、内部で TPRoute を増やさず
//  このビュー1つが状態機械のホストになる（PairSession と同じ考え方）。
//

import SwiftUI
import SwiftData

@MainActor
struct GokonSessionView: View {

    @State private var viewModel = GokonSessionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .onChange(of: viewModel.stage) { _, newStage in
                handleStageChange(newStage)
            }
            .animation(reduceMotion ? .none : .snappy(duration: 0.3), value: viewModel.stage)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .setup:
            GokonSetupView(viewModel: viewModel, onClose: closeFlow)
        case .turn(let phase):
            GokonTurnView(viewModel: viewModel, phase: phase, onClose: closeFlow)
        case .leaderboard:
            GokonLeaderboardView(viewModel: viewModel, onClose: closeFlow)
        case .finalReveal:
            GokonFinalRankingView(viewModel: viewModel, onClose: closeFlow)
        case .penalty:
            GokonPenaltyRouletteView(viewModel: viewModel, onClose: closeFlow)
        }
    }

    private func handleStageChange(_ stage: GokonSessionViewModel.Stage) {
        if stage == .leaderboard {
            viewModel.persistLastTurn(in: modelContext)
        }
    }

    private func closeFlow() {
        viewModel.restart()
        dismiss()
    }
}

// MARK: - Previews

#Preview {
    GokonSessionView()
        .modelContainer(TPModelContainer.preview)
}
