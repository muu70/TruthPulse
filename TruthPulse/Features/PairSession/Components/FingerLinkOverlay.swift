//
//  FingerLinkOverlay.swift
//  TruthPulse
//
//  2 本の指の位置に発光を出し、あいだをラインで結びます。
//  近づくほどラインが太く明るくなり、触れ合うと 1 つの光に融合します。
//

import SwiftUI

struct FingerLinkOverlay: View {

    let points: [CGPoint]
    /// 0.0（遠い）〜 1.0（触れ合っている）
    let closeness: Double
    let isMeasuring: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        closeness >= 0.995 ? TPColor.truth : TPColor.deceit
    }

    var body: some View {
        ZStack {
            if points.count >= 2 {
                link(from: points[0], to: points[1])
            }
            ForEach(points.indices, id: \.self) { index in
                fingerGlow(at: points[index], index: index)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Parts

    @ViewBuilder
    private func link(from a: CGPoint, to b: CGPoint) -> some View {
        let width: CGFloat = 1.5 + CGFloat(closeness) * 5
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)

        Path { path in
            path.move(to: a)
            path.addLine(to: b)
        }
        .stroke(linkGradient, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .shadow(color: tint.opacity(closeness * 0.9), radius: 10)
        .opacity(0.35 + closeness * 0.65)

        if isMeasuring {
            syncBadge
                .position(x: mid.x, y: mid.y - 34)
        }
    }

    private var linkGradient: LinearGradient {
        LinearGradient(
            colors: [TPColor.deceit, tint, TPColor.cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var syncBadge: some View {
        let percent: Int = Int(closeness * 100)
        let label: String = "同調率 " + String(percent) + "%"
        let color: Color = closeness >= 0.995 ? TPColor.truthText : TPColor.cyan

        return Text(label)
            .font(TPFont.mono(11))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background {
                ZStack {
                    Capsule().fill(TPColor.void.opacity(0.85))
                    Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1)
                }
            }
    }

    private func fingerGlow(at point: CGPoint, index: Int) -> some View {
        let base: Color = index == 0 ? TPColor.deceit : TPColor.cyan
        let color: Color = closeness >= 0.995 ? TPColor.truth : base
        let size: CGFloat = 58 + CGFloat(closeness) * 14

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.55), color.opacity(0.05)],
                        center: .center, startRadius: 2, endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 8)

            Circle()
                .strokeBorder(color.opacity(0.85), lineWidth: 2)
                .frame(width: size, height: size)

            Circle()
                .fill(color.opacity(0.30))
                .frame(width: size * 0.45, height: size * 0.45)
        }
        .position(point)
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        FingerLinkOverlay(
            points: [CGPoint(x: 90, y: 320), CGPoint(x: 250, y: 360)],
            closeness: 0.55,
            isMeasuring: true
        )
    }
    .preferredColorScheme(.dark)
}
