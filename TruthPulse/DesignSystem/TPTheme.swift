//
//  TPTheme.swift
//  TruthPulse
//
//  Spatial Bio-Tech デザイントークン。
//  モックアップの CSS 変数と 1:1 で対応しています。
//

import SwiftUI

// MARK: - Color

enum TPColor {

    // Surfaces
    static let void = Color(hex: 0x05060F)
    static let deep = Color(hex: 0x0A0D1E)
    /// Reduce Transparency 時にガラスの代わりに使う不透明サーフェス
    static let opaqueSurface = Color(hex: 0x141830)

    // Accents
    static let cyan = Color(hex: 0x34E5FF)
    static let electric = Color(hex: 0x2E7BFF)
    static let purple = Color(hex: 0x7B4DFF)

    // Semantics
    static let deceit = Color(hex: 0xFF3D9A)
    static let deceitText = Color(hex: 0xFF8FC2)
    static let truth = Color(hex: 0x29F2A0)
    static let truthText = Color(hex: 0x7CFFCB)
    static let caution = Color(hex: 0xFFB020)

    // Text (すべて deep 背景に対して WCAG AA 以上)
    static let textPrimary = Color(hex: 0xF2F6FF)   // 17.8:1
    static let textSecondary = Color(hex: 0xA8B2D1) // 9.1:1
    static let textTertiary = Color(hex: 0x8290B5)  // 6.1:1

    // Strokes
    static let stroke = Color.white.opacity(0.12)
    static let strokeAccent = TPColor.cyan.opacity(0.35)

    /// スコアリング / CTA 共通のブランドグラデーション
    static let brandGradient = LinearGradient(
        colors: [cyan, electric, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 画面全体の背景（2 層のラジアルグラデーション）
    @ViewBuilder
    static var backdrop: some View {
        ZStack {
            deep
            RadialGradient(
                colors: [electric.opacity(0.28), .clear],
                center: UnitPoint(x: 0.5, y: -0.08),
                startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [purple.opacity(0.22), .clear],
                center: UnitPoint(x: 1.0, y: 1.0),
                startRadius: 0, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Typography

enum TPFont {

    /// スコア用。SF Pro Display 相当 + 等幅数字で桁変動時のガタつきを防ぐ。
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default).monospacedDigit()
    }

    static func title(_ size: CGFloat = 19) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// 全角大文字 + tracking +18% の計器ラベル。
    func tpLabelStyle(size: CGFloat = 11) -> some View {
        self.font(.system(size: size, weight: .semibold))
            .tracking(size * 0.18)
            .textCase(.uppercase)
            .foregroundStyle(TPColor.textTertiary)
    }

    /// 本文行間 1.35 倍。
    func tpLineSpacing(_ fontSize: CGFloat) -> some View {
        self.lineSpacing(fontSize * 0.35)
    }
}

// MARK: - Metrics

enum TPMetrics {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let buttonRadius: CGFloat = 20
    static let padRadius: CGFloat = 26
    static let grid: CGFloat = 8

    /// 心拍 1 周期。脈動アニメーションと触覚フィードバックが共有する。
    static let heartbeatPeriod: Duration = .milliseconds(1_100)
    /// 計測時間（ソロ）
    static let samplingDuration: TimeInterval = 8.0
    /// 計測時間（デュオ）。顔を寄せ続けるのは疲れるので短め。
    static let duoSamplingDuration: TimeInterval = 6.0
    /// 生体データの更新レート
    static let sampleInterval: Duration = .milliseconds(50)
}
