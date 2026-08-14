//
//  ModeCard.swift
//  TruthPulse
//
//  モード選択カード。選択中のものだけが Cyan の発光ボーダーを持ちます。
//

import SwiftUI

struct ModeCard: View {

    struct Palette {
        let start: Color
        let end: Color

        static let solo = Palette(start: TPColor.cyan, end: TPColor.electric)
        static let duo = Palette(start: TPColor.deceit, end: TPColor.purple)
        static let pair = Palette(start: TPColor.truth, end: TPColor.cyan)
        static let gokon = Palette(start: TPColor.purple, end: TPColor.caution)
        static let neutral = Palette(start: .white, end: .white)
    }

    let icon: String
    let title: String
    let subtitle: String
    var palette: Palette = .solo
    var isSelected: Bool = false
    /// 未実装機能に付ける「準備中」バッジ。
    var badge: String?
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                iconTile

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TPColor.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9.5, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(TPColor.caution)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background {
                                    Capsule().fill(TPColor.caution.opacity(0.16))
                                    Capsule().strokeBorder(TPColor.caution.opacity(0.4), lineWidth: 1)
                                }
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(TPColor.textTertiary)
                        .tpLineSpacing(12)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TPColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 52)
            .glassCard(padding: 18, selected: isSelected)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // MARK: Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge == nil ? title : "\(title)、\(badge!)")
        .accessibilityValue(subtitle)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var iconTile: some View {
        Image(systemName: icon)
            .font(.system(size: typeSize.isAccessibilitySize ? 20 : 23, weight: .medium))
            .foregroundStyle(palette.start)
            .frame(width: 52, height: 52)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                shape.fill(
                    LinearGradient(
                        colors: [palette.start.opacity(0.28), palette.end.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                shape.strokeBorder(palette.start.opacity(0.4), lineWidth: 1)
            }
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        VStack(spacing: 14) {
            ModeCard(icon: "person.fill", title: "ソロ・スキャン",
                     subtitle: "指を置いて、自分の生体反応を計測",
                     palette: .solo, isSelected: true) {}
            ModeCard(icon: "person.2.fill", title: "デュオ・スキャン",
                     subtitle: "2人で顔を寄せて、相性と本音を判定",
                     palette: .duo, badge: "準備中", isEnabled: false) {}
            ModeCard(icon: "list.bullet.rectangle", title: "セッション履歴",
                     subtitle: "今夜のスコア 8件",
                     palette: .neutral) {}
        }
        .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
