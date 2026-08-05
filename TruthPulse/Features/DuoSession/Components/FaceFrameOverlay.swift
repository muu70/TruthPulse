//
//  FaceFrameOverlay.swift
//  TruthPulse
//
//  顔にかぶせる計測フレーム。コーナーブラケット + フェイスメッシュ +
//  擬似生体ヒートマップの 3 レイヤー構成です。
//

import SwiftUI

struct FaceFrameOverlay: View {
    let rect: CGRect
    let tint: Color
    /// ロック済み（＝スキャン可能）かどうか
    let isLocked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 生体ヒートマップ（頬 2 点 + 口元 1 点）
            heatmap

            // フェイスメッシュ。顔が見えなくならないよう薄く、中央だけ。
            FaceMesh(spacing: 14)
                .stroke(tint.opacity(0.14), lineWidth: 0.8)
                .mask {
                    RadialGradient(
                        colors: [.black, .clear],
                        center: UnitPoint(x: 0.5, y: 0.45),
                        startRadius: 0,
                        endRadius: min(rect.width, rect.height) * 0.55
                    )
                }

            CornerBrackets(length: min(rect.width, rect.height) * 0.26)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: tint.opacity(0.7), radius: isLocked ? 10 : 4)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: rect)
        .allowsHitTesting(false)
    }

    private var heatmap: some View {
        ZStack {
            heatBlob(x: 0.24, y: 0.50, color: tint, size: 0.26)
            heatBlob(x: 0.76, y: 0.50, color: tint, size: 0.26)
            heatBlob(x: 0.50, y: 0.76, color: isLocked ? TPColor.truth : TPColor.caution, size: 0.22)
        }
        .blendMode(.plusLighter)
    }

    private func heatBlob(x: Double, y: Double, color: Color, size: Double) -> some View {
        let w: CGFloat = rect.width * size
        let h: CGFloat = rect.height * size * 0.7

        return Ellipse()
            .fill(color.opacity(0.30))
            .frame(width: w, height: h)
            .blur(radius: 10)
            .position(x: rect.width * x, y: rect.height * y)
    }
}

// MARK: - Shapes

/// 四隅の L 字ブラケット。
private struct CornerBrackets: Shape {
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = length

        // 左上
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // 右上
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // 右下
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // 左下
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return path
    }
}

private struct FaceMesh: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: - Link line

/// 2 つの顔を結ぶ発光ライン。SYNC が高いほど太く明るくなる。
struct FaceLinkLine: View {
    let from: CGPoint
    let to: CGPoint
    let sync: Double

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(
                LinearGradient(colors: [TPColor.deceit, TPColor.cyan],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1 + sync * 3, lineCap: .round)
            )
            .shadow(color: TPColor.cyan.opacity(sync * 0.8), radius: 8)
        }
        .opacity(0.35 + sync * 0.65)
        .allowsHitTesting(false)
    }
}

#Preview {
    GeometryReader { proxy in
        ZStack {
            SimulatedCameraBackdrop()

            let left = CGRect(x: proxy.size.width * 0.10, y: proxy.size.height * 0.32,
                              width: 130, height: 165)
            let right = CGRect(x: proxy.size.width * 0.52, y: proxy.size.height * 0.32,
                               width: 130, height: 165)

            FaceLinkLine(
                from: CGPoint(x: left.midX, y: left.midY),
                to: CGPoint(x: right.midX, y: right.midY),
                sync: 0.68
            )
            FaceFrameOverlay(rect: left, tint: TPColor.deceit, isLocked: false)
            FaceFrameOverlay(rect: right, tint: TPColor.cyan, isLocked: true)
        }
    }
    .preferredColorScheme(.dark)
}
