//
//  ShareCardView.swift
//  TruthPulse
//
//  SNS 共有用カード（タイポ主役レイアウト）。
//
//  タイムラインで縮小表示されても「何の結果か」が読めることを最優先に、
//  判定の言葉をカードの上半分いっぱいに置いています。
//
//  ImageRenderer で画像化するため、material・Environment 依存・
//  アニメーションは使いません。
//

import SwiftUI
import UIKit

struct ShareCardView: View {
    let session: ScanSession

    /// 1080 × 1350px（4:5）で書き出す。
    static let size = CGSize(width: 360, height: 450)

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            content
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Background

    private var background: some View {
        let accent: Color = session.verdict.accentColor

        return ZStack {
            LinearGradient(
                colors: [accentTintTop, Color(hex: 0x0A0D1E), Color(hex: 0x120A32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GridPattern(spacing: 24)
                .stroke(accent.opacity(0.10), lineWidth: 1)
            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: UnitPoint(x: 0.15, y: 0.18),
                startRadius: 0, endRadius: 300
            )
        }
    }

    private var accentTintTop: Color {
        session.verdict == .truthful ? Color(hex: 0x0A2E22) : Color(hex: 0x2B0A22)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            headlineBlock
            Spacer(minLength: 0)
            divider
            questionBlock
            Spacer(minLength: 0)
            scoreBlock
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .padding(.bottom, 24)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("TRUTHPULSE")
                .font(.system(size: 10, weight: .heavy))
                .tracking(3.5)
                .foregroundStyle(session.verdict.textColor)
            Spacer()
            Circle()
                .fill(session.verdict.accentColor)
                .frame(width: 7, height: 7)
        }
    }

    /// 判定の言葉 ＋ ウソミ。カードの主役。
    private var headlineBlock: some View {
        ZStack(alignment: .topLeading) {
            Text(session.headline)
                .font(.system(size: 46, weight: .heavy))
                .tracking(-2)
                .foregroundStyle(headlineGradient)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            UsomiView(score: session.honestyScore, unit: 54, animated: false)
                .offset(x: 152, y: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headlineGradient: LinearGradient {
        LinearGradient(
            colors: [session.verdict.textColor, session.verdict.accentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 1)
            .padding(.top, 14)
    }

    @ViewBuilder
    private var questionBlock: some View {
        if session.question.isEmpty {
            Text(session.mode.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: 0xA8B2D1))
                .padding(.top, 14)
        } else {
            Text(questionLine)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0xA8B2D1))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
    }

    private var questionLine: String {
        "「" + session.question + "」"
    }

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(session.honestyScore))
                    .font(.system(size: 48, weight: .heavy).monospacedDigit())
                    .tracking(-2)
                    .foregroundStyle(.white)
                Text("／100")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8290B5))
            }

            HStack(spacing: 0) {
                Text(footerLine)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: 0x8290B5))
                Spacer()
                Text("#TruthPulse")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(session.verdict.textColor)
            }
        }
    }

    private var footerLine: String {
        "誠実度スコア ・ 確信度 " + String(session.confidence) + "%"
    }
}

// MARK: - Shapes

/// 背景のデータグリッド。Canvas は ImageRenderer で扱いづらいため Shape で描く。
private struct GridPattern: Shape {
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

// MARK: - Renderer

enum ShareCardRenderer {
    /// @3x で書き出す（1080 × 1350px 相当）。
    @MainActor
    static func render(_ session: ScanSession) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(session: session))
        renderer.scale = 3
        renderer.isOpaque = true
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Previews

#Preview("嘘") {
    ZStack {
        Color.black
        ShareCardView(session: ScanSession.mocks[0])
    }
    .ignoresSafeArea()
}

#Preview("本当") {
    ZStack {
        Color.black
        ShareCardView(session: ScanSession.mocks[1])
    }
    .ignoresSafeArea()
}
