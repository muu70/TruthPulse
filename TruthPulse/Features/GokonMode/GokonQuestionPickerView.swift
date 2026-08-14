//
//  GokonQuestionPickerView.swift
//  TruthPulse
//
//  お題カテゴリタブ・お題カード・引き直し・計測開始 CTA。
//  デッキのお題だけで最後まで進められ、手入力は任意の補助手段。
//

import SwiftUI

@MainActor
struct GokonQuestionPickerView: View {

    let viewModel: GokonSessionViewModel

    @State private var isShowingCustomField = false
    @State private var customQuestionDraft = ""

    var body: some View {
        VStack(spacing: TPMetrics.grid * 1.5) {
            categoryTabs
            questionCard
            rerollButton
            TPButton(title: startTitle, systemImage: "play.fill") {
                viewModel.beginTurnScan()
            }
            customQuestionToggle
            if isShowingCustomField {
                customQuestionField
            }
        }
        .transition(.opacity)
    }

    private var startTitle: String {
        viewModel.currentPlayerDisplayName + "さんを計測する"
    }

    // MARK: - Category

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(GokonQuestionCategory.allCases) { category in
                categoryTab(category)
            }
        }
    }

    private func categoryTab(_ category: GokonQuestionCategory) -> some View {
        let selected = viewModel.selectedCategory == category

        return Button { viewModel.selectCategory(category) } label: {
            Text(category.displayName)
                .font(.system(size: 11.5, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(selected ? Color(hex: 0x00121F) : TPColor.textSecondary)
                .background { tabBackground(selected: selected) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func tabBackground(selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        if selected {
            shape.fill(TPColor.brandGradient)
        } else {
            GlassBackground(cornerRadius: 11)
        }
    }

    // MARK: - Question

    private var questionCard: some View {
        VStack(spacing: 10) {
            Text(viewModel.question)
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.3)
                .multilineTextAlignment(.center)
                .foregroundStyle(TPColor.textPrimary)
                .tpLineSpacing(19)
            Text(deckLabel)
                .font(TPFont.mono(10))
                .foregroundStyle(TPColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 22)
        .accessibilityElement(children: .combine)
    }

    private var deckLabel: String {
        viewModel.selectedCategory.displayName + "デッキ"
    }

    private var rerollButton: some View {
        Button { viewModel.rerollQuestion() } label: {
            HStack(spacing: 6) {
                Image(systemName: "shuffle")
                Text("別のお題にする")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TPColor.cyan)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom question（任意）

    private var customQuestionToggle: some View {
        Button {
            isShowingCustomField.toggle()
        } label: {
            Text(isShowingCustomField ? "デッキのお題に戻す" : "自分で質問を入力")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TPColor.textTertiary)
        }
        .buttonStyle(.plain)
    }

    private var customQuestionField: some View {
        TextField("質問を入力", text: $customQuestionDraft, axis: .vertical)
            .font(TPFont.body(14))
            .foregroundStyle(TPColor.textPrimary)
            .tint(TPColor.cyan)
            .lineLimit(1...3)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background { GlassBackground(cornerRadius: 14) }
            .accessibilityLabel("質問を入力")
            .onChange(of: customQuestionDraft) { _, newValue in
                guard !newValue.isEmpty else { return }
                viewModel.question = newValue
            }
    }
}
