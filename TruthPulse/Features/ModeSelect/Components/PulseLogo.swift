//
//  PulseLogo.swift
//  TruthPulse
//
//  3 重リングが心拍と同じ周期で広がるブランドマーク。
//

import SwiftUI

struct PulseLogo: View {
    var size: CGFloat = 96
    /// リングの拡散周期。心拍 1.1 秒 ×
    var period: Double = 2.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private let ringCount = 3

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<ringCount, id: \.self) { index in
                    Circle()
                        .strokeBorder(TPColor.cyan.opacity(0.5), lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .scaleEffect(expanded ? 1.15 : 0.55)
                        .opacity(expanded ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: period)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * period / Double(ringCount)),
                            value: expanded
                        )
                }
            } else {
                Circle()
                    .strokeBorder(TPColor.cyan.opacity(0.35), lineWidth: 1.5)
                    .frame(width: size * 0.9, height: size * 0.9)
            }

            // 発光コア
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x9BF3FF), TPColor.electric, TPColor.purple],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 1, endRadius: size * 0.42
                    )
                )
                .frame(width: size * 0.60, height: size * 0.60)
                .shadow(color: TPColor.cyan.opacity(0.65), radius: size * 0.45)
        }
        .frame(width: size, height: size)
        .onAppear { expanded = true }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        PulseLogo()
    }
    .preferredColorScheme(.dark)
}
