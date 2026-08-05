//
//  UsomiView.swift
//  TruthPulse
//
//  テーマキャラクター「ウソミ」。
//
//  すべて SwiftUI の図形で描いています（画像アセットなし）。
//  スコアが低いほど鼻が長く伸びるので、数字を読まなくても結果が伝わります。
//
//  座標はすべて `unit`（＝体の直径）に対する倍率で置いています。
//  型チェックを軽く保つため、計算結果はいったん CGFloat 定数に落としています。
//

import SwiftUI

struct UsomiView: View {

    /// 0–100。低いほど鼻が伸びる。
    let score: Int
    /// 体の直径。全体のフレームはこの 2.6 倍 × 1.3 倍。
    var unit: CGFloat = 120
    /// 登場時に鼻を伸ばすか。ImageRenderer で書き出すときは false。
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var noseProgress: Double = 0
    @State private var bodyScale: CGFloat = 0.82

    // MARK: - Derived geometry

    private var verdict: Verdict { Verdict(score: score) }

    /// 体の中心。鼻が右へ伸びるので、左寄りに置く。
    private var center: CGPoint {
        CGPoint(x: unit * 0.62, y: unit * 0.70)
    }

    private var frameSize: CGSize {
        CGSize(width: unit * 2.60, height: unit * 1.35)
    }

    /// 鼻の最終的な長さ。100 点でほぼ団子鼻、0 点で体の 1.35 倍。
    private var noseLength: CGFloat {
        let t: CGFloat = CGFloat(score.clamped(to: 0...100)) / 100
        return unit * (0.10 + (1 - t) * 1.35)
    }

    private var bodyFill: Color {
        verdict == .truthful ? Color(hex: 0x123328) : Color(hex: 0x2A0F33)
    }

    private var trim: Color { verdict.accentColor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            horns
            body_
            tail
            eyes
            mouth
            nose
        }
        .frame(width: frameSize.width, height: frameSize.height, alignment: .topLeading)
        .scaleEffect(bodyScale, anchor: .leading)
        .task { await animateIn() }
        .accessibilityHidden(true)
    }

    private func animateIn() async {
        guard animated, !reduceMotion else {
            noseProgress = 1
            bodyScale = 1
            return
        }
        noseProgress = 0
        bodyScale = 0.82
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { bodyScale = 1 }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.easeOut(duration: 0.55)) { noseProgress = 1 }
    }

    // MARK: - Parts

    private var body_: some View {
        let d: CGFloat = unit

        return ZStack {
            Circle().fill(bodyFill)
            Circle().strokeBorder(trim.opacity(0.65), lineWidth: unit * 0.016)
        }
        .frame(width: d, height: d)
        .position(center)
        .shadow(color: trim.opacity(0.35), radius: unit * 0.28)
    }

    private var horns: some View {
        let w: CGFloat = unit * 0.22
        let h: CGFloat = unit * 0.26
        let dx: CGFloat = unit * 0.30
        let dy: CGFloat = unit * 0.44

        return ZStack {
            HornShape()
                .fill(trim)
                .frame(width: w, height: h)
                .position(x: center.x - dx, y: center.y - dy)
            HornShape()
                .fill(trim)
                .frame(width: w, height: h)
                .scaleEffect(x: -1, y: 1)
                .position(x: center.x + dx, y: center.y - dy)
        }
        .opacity(0.9)
    }

    private var eyes: some View {
        let rx: CGFloat = unit * 0.105
        let ry: CGFloat = unit * 0.135
        let dx: CGFloat = unit * 0.19
        let dy: CGFloat = unit * 0.10

        return ZStack {
            eye(at: CGPoint(x: center.x - dx, y: center.y - dy), rx: rx, ry: ry)
            eye(at: CGPoint(x: center.x + dx, y: center.y - dy), rx: rx, ry: ry)
        }
    }

    private func eye(at point: CGPoint, rx: CGFloat, ry: CGFloat) -> some View {
        // 嘘のときは目を見開き、本当のときは細める
        let openness: CGFloat = verdict == .truthful ? 0.62 : 1.0
        let pupil: CGFloat = unit * 0.055
        let pupilDrop: CGFloat = unit * 0.012

        return ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.94))
                .frame(width: rx * 2, height: ry * 2 * openness)
            Circle()
                .fill(Color(hex: 0x1B1436))
                .frame(width: pupil * 2, height: pupil * 2)
                .offset(y: pupilDrop)
        }
        .position(point)
    }

    private var mouth: some View {
        let w: CGFloat = unit * 0.30
        let h: CGFloat = unit * 0.11
        let y: CGFloat = center.y + unit * 0.24

        return MouthShape(smiling: verdict == .truthful)
            .stroke(verdict.textColor, style: StrokeStyle(lineWidth: unit * 0.030, lineCap: .round))
            .frame(width: w, height: h)
            .position(x: center.x - unit * 0.06, y: y)
    }

    private var nose: some View {
        let start: CGPoint = CGPoint(x: center.x + unit * 0.28, y: center.y + unit * 0.05)
        let length: CGFloat = noseLength * CGFloat(noseProgress)
        let tipX: CGFloat = start.x + length
        let tipY: CGFloat = start.y + length * 0.055
        let thickness: CGFloat = unit * 0.075
        let tip: CGFloat = unit * 0.052

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: start)
                path.addLine(to: CGPoint(x: tipX, y: tipY))
            }
            .stroke(TPColor.caution, style: StrokeStyle(lineWidth: thickness, lineCap: .round))

            Circle()
                .fill(TPColor.caution)
                .frame(width: tip * 2, height: tip * 2)
                .position(x: tipX, y: tipY)
        }
        .shadow(color: TPColor.caution.opacity(0.45), radius: unit * 0.10)
    }

    private var tail: some View {
        let x: CGFloat = center.x - unit * 0.44
        let y: CGFloat = center.y + unit * 0.30

        return TailShape()
            .stroke(trim, style: StrokeStyle(lineWidth: unit * 0.032, lineCap: .round))
            .frame(width: unit * 0.30, height: unit * 0.34)
            .position(x: x, y: y)
            .opacity(0.85)
    }
}

// MARK: - Shapes

private struct HornShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY - rect.height * 0.35))
        path.closeSubpath()
        return path
    }
}

private struct MouthShape: Shape {
    let smiling: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: smiling ? rect.minY : rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: smiling ? rect.minY : rect.maxY),
            control: CGPoint(x: rect.midX, y: smiling ? rect.maxY * 1.6 : rect.minY - rect.height * 0.6)
        )
        return path
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY),
            control: CGPoint(x: rect.minX - rect.width * 0.2, y: rect.midY)
        )
        return path
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("スコア別") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([96, 78, 64, 52, 41, 27, 8], id: \.self) { score in
                HStack(spacing: 12) {
                    Text(String(score))
                        .font(TPFont.score(20))
                        .foregroundStyle(Verdict(score: score).textColor)
                        .frame(width: 40, alignment: .trailing)
                    UsomiView(score: score, unit: 62, animated: false)
                }
            }
        }
        .padding(20)
    }
    .background { TPColor.backdrop }
    .preferredColorScheme(.dark)
}
