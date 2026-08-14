//
//  GokonRouletteWheel.swift
//  TruthPulse
//
//  罰ゲームルーレットの円盤。画像は使わず Shape で描く。
//  20分割だと文字は読めないので、円盤にはラベルを乗せない
//  （結果は回転後に別途大きく表示する）。
//

import SwiftUI

struct GokonRouletteWheel: View {
    let sliceCount: Int
    let rotation: Angle

    private static let palette: [Color] = [TPColor.cyan, TPColor.purple, TPColor.deceit, TPColor.truth]

    var body: some View {
        ZStack {
            ForEach(0..<sliceCount, id: \.self) { index in
                slice(at: index)
            }
            hub
        }
        .rotationEffect(rotation)
        .accessibilityHidden(true)
    }

    private func slice(at index: Int) -> some View {
        let color = Self.palette[index % Self.palette.count]

        return ZStack {
            WheelSlice(index: index, total: sliceCount).fill(color.opacity(0.45))
            WheelSlice(index: index, total: sliceCount).stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var hub: some View {
        Circle()
            .fill(TPColor.deep)
            .overlay { Circle().strokeBorder(TPColor.caution.opacity(0.5), lineWidth: 2) }
            .frame(width: 56, height: 56)
    }
}

private struct WheelSlice: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let anglePerSlice = 360.0 / Double(total)
        let start = Angle(degrees: anglePerSlice * Double(index) - 90)
        let end = Angle(degrees: anglePerSlice * Double(index + 1) - 90)

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        TPColor.backdrop
        GokonRouletteWheel(sliceCount: GokonPenaltyDeck.all.count, rotation: .zero)
            .frame(width: 220, height: 220)
    }
    .preferredColorScheme(.dark)
}
