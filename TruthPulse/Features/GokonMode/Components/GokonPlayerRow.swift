//
//  GokonPlayerRow.swift
//  TruthPulse
//
//  メンバー設定画面の1行。名前入力（任意）+ 削除ボタン。
//

import SwiftUI

struct GokonPlayerRow: View {
    let index: Int
    @Binding var name: String
    let canRemove: Bool
    let onRemove: () -> Void

    private static let avatarPalette: [Color] = [TPColor.cyan, TPColor.deceit, TPColor.truth, TPColor.purple]

    var body: some View {
        HStack(spacing: 11) {
            avatar
            TextField(placeholder, text: $name)
                .font(TPFont.body(14))
                .foregroundStyle(TPColor.textPrimary)
                .tint(TPColor.cyan)
                .accessibilityLabel(placeholder + "の名前、任意")

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(TPColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(placeholder + "を削除")
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
    }

    private var placeholder: String { "プレイヤー" + String(index + 1) }

    private var avatar: some View {
        let color = Self.avatarPalette[index % Self.avatarPalette.count]

        return Text(String(index + 1))
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background {
                Circle().fill(color.opacity(0.18))
                Circle().strokeBorder(color.opacity(0.4), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var name = "ユウキ"

    ZStack {
        TPColor.backdrop
        GokonPlayerRow(index: 0, name: $name, canRemove: true) {}
            .glassCard()
            .padding()
    }
    .preferredColorScheme(.dark)
}
