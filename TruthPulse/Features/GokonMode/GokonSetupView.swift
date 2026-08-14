//
//  GokonSetupView.swift
//  TruthPulse
//
//  画面B: メンバー設定。人数チップ・名前入力・シャッフル切替。
//  手間をかけさせると場が冷えるので、最短2タップで抜けられる設計。
//

import SwiftUI

@MainActor
struct GokonSetupView: View {

    @Bindable var viewModel: GokonSessionViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TPColor.backdrop
            ScrollView {
                VStack(spacing: TPMetrics.grid * 2) {
                    countChips
                    playerList
                    shuffleToggle
                    startButton
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TPColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background { GlassBackground(cornerRadius: 12) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()
            Text("メンバー").font(TPFont.title()).foregroundStyle(TPColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
        .padding(.horizontal, TPMetrics.screenPadding)
        .padding(.bottom, TPMetrics.grid)
    }

    // MARK: - Count

    private var countChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("人数").tpLabelStyle(size: 10)
            HStack(spacing: 7) {
                ForEach([2, 4, 6, 8], id: \.self) { count in
                    countChip(count)
                }
                addChip
            }
        }
    }

    private func countChip(_ count: Int) -> some View {
        let selected = viewModel.players.count == count

        return Button { viewModel.setPlayerCount(count) } label: {
            Text(String(count))
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color(hex: 0x00121F) : TPColor.textSecondary)
                .background { chipBackground(selected: selected) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(count) + "人")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var addChip: some View {
        Button { viewModel.addPlayer() } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(TPColor.textSecondary)
                .background { GlassBackground(cornerRadius: 14) }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isMaxPlayerCount)
        .opacity(viewModel.isMaxPlayerCount ? 0.4 : 1)
        .accessibilityLabel("1人追加")
    }

    @ViewBuilder
    private func chipBackground(selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if selected {
            shape.fill(TPColor.brandGradient)
        } else {
            GlassBackground(cornerRadius: 14)
        }
    }

    // MARK: - Player list

    private var playerList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, _ in
                GokonPlayerRow(
                    index: index,
                    name: $viewModel.players[index].name,
                    canRemove: !viewModel.isMinPlayerCount
                ) {
                    viewModel.removePlayer(at: index)
                }
                if index < viewModel.players.count - 1 { rowDivider }
            }
        }
        .padding(.horizontal, 4)
        .background { GlassBackground() }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    // MARK: - Shuffle

    private var shuffleToggle: some View {
        HStack(spacing: 10) {
            Image(systemName: "shuffle")
                .font(.system(size: 13))
                .foregroundStyle(TPColor.cyan)
            Text("順番をシャッフル")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TPColor.textPrimary)
            Spacer()
            Toggle("順番をシャッフル", isOn: $viewModel.shuffleOrder)
                .labelsHidden()
                .tint(TPColor.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background { GlassBackground(cornerRadius: 16) }
    }

    // MARK: - Start

    private var startButton: some View {
        VStack(spacing: 9) {
            TPButton(title: "スタート", systemImage: "play.fill") {
                viewModel.startGame()
            }
            .disabled(!viewModel.canStartGame)
            .opacity(viewModel.canStartGame ? 1 : 0.4)

            Text("名前は空欄でも「プレイヤー1」のように進みます")
                .font(.system(size: 11))
                .foregroundStyle(TPColor.textTertiary)
        }
    }
}

// MARK: - Previews

#Preview {
    GokonSetupView(viewModel: GokonSessionViewModel(), onClose: {})
}
