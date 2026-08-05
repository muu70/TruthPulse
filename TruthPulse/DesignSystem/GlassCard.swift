//
//  GlassCard.swift
//  TruthPulse
//
//  半透明ガラスレイヤー。Reduce Transparency に自動で追従します。
//

import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat = TPMetrics.cardRadius
    var tint: Color = .white
    var tintOpacity: Double = 0.055
    var strokeColor: Color = TPColor.stroke
    var strokeWidth: CGFloat = 1

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(reduceTransparency
                  ? AnyShapeStyle(TPColor.opaqueSurface)
                  : AnyShapeStyle(.ultraThinMaterial))
            .overlay {
                if !reduceTransparency {
                    shape.fill(tint.opacity(tintOpacity))
                }
            }
            .overlay {
                shape.strokeBorder(strokeColor, lineWidth: strokeWidth)
            }
    }
}

extension View {
    /// 標準のガラスカード。`selected` が true のときだけ Cyan の発光ボーダーを持つ。
    func glassCard(
        cornerRadius: CGFloat = TPMetrics.cardRadius,
        padding: CGFloat = TPMetrics.cardPadding,
        selected: Bool = false
    ) -> some View {
        self
            .padding(padding)
            .background {
                GlassBackground(
                    cornerRadius: cornerRadius,
                    tint: selected ? TPColor.cyan : .white,
                    tintOpacity: selected ? 0.10 : 0.055,
                    strokeColor: selected ? TPColor.cyan.opacity(0.55) : TPColor.stroke
                )
            }
            .shadow(color: selected ? TPColor.cyan.opacity(0.35) : .clear,
                    radius: 20, y: 8)
    }
}

// MARK: - Pill

struct TPPill: View {
    enum Kind {
        case live, ok, neutral

        var tint: Color {
            switch self {
            case .live: TPColor.deceit
            case .ok: TPColor.truth
            case .neutral: TPColor.cyan
            }
        }

        var textColor: Color {
            switch self {
            case .live: TPColor.deceitText
            case .ok: TPColor.truthText
            case .neutral: TPColor.cyan
            }
        }
    }

    let kind: Kind
    let text: String
    var showsPulsingDot: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotVisible = true

    var body: some View {
        HStack(spacing: 6) {
            if showsPulsingDot {
                Circle()
                    .fill(kind.textColor)
                    .frame(width: 6, height: 6)
                    .opacity(dotVisible ? 1 : 0.25)
                    .animation(reduceMotion ? nil
                               : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                               value: dotVisible)
                    .onAppear { dotVisible = false }
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(kind.textColor)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(kind.tint.opacity(0.16))
            Capsule().strokeBorder(kind.tint.opacity(0.40), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - CTA Button

struct TPButton: View {
    enum Style { case primary, ghost }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(style == .primary ? Color(hex: 0x00121F) : TPColor.textPrimary)
            .background {
                let shape = RoundedRectangle(cornerRadius: TPMetrics.buttonRadius, style: .continuous)
                switch style {
                case .primary:
                    shape.fill(TPColor.brandGradient)
                case .ghost:
                    GlassBackground(cornerRadius: TPMetrics.buttonRadius)
                }
            }
            .shadow(color: style == .primary ? TPColor.cyan.opacity(0.45) : .clear,
                    radius: 22, y: 10)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: TPMetrics.buttonRadius, style: .continuous))
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        VStack(spacing: 16) {
            Text("Honesty Index").tpLabelStyle()
            HStack {
                TPPill(kind: .live, text: "REC", showsPulsingDot: true)
                TPPill(kind: .ok, text: "6人")
            }
            VStack(alignment: .leading) {
                Text("ガラスカード").font(TPFont.title())
                Text("Reduce Transparency で不透明化します")
                    .font(TPFont.body(13))
                    .foregroundStyle(TPColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            TPButton(title: "スキャンを開始", systemImage: "play.fill") {}
        }
        .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
