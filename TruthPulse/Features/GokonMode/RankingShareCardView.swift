//
//  RankingShareCardView.swift
//  TruthPulse
//
//  合コンモードのランキング結果シェアカード。
//
//  単一結果の ShareCardView とはレイアウトを分けている
//  （BACKLOG.md の受け入れ条件）。ImageRenderer で書き出すため、
//  material・Environment 依存・アニメーションは使わない（ShareCardView と同じ制約）。
//

import SwiftUI
import UIKit

struct RankingShareCardData {
    struct Entry: Identifiable {
        let rank: Int
        let name: String
        let score: Int
        var id: Int { rank }
    }

    let groupID: UUID
    let date: Date
    let entries: [Entry]
}

struct RankingShareCardView: View {
    let data: RankingShareCardData

    /// ShareCardView と同じ 4:5。書き出しは @3x（1080 × 1350px 相当）。
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

    private var winner: RankingShareCardData.Entry? { data.entries.first }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B0A22), Color(hex: 0x0A0D1E), Color(hex: 0x120A32)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GridPattern(spacing: 24)
                .stroke(TPColor.deceit.opacity(0.10), lineWidth: 1)
            RadialGradient(
                colors: [TPColor.deceit.opacity(0.22), .clear],
                center: UnitPoint(x: 0.15, y: 0.18), startRadius: 0, endRadius: 300
            )
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            winnerBlock
            divider
            rankList
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("TRUTHPULSE")
                .font(.system(size: 10, weight: .heavy))
                .tracking(3.5)
                .foregroundStyle(TPColor.deceitText)
            Spacer()
            Text("合コンモード")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(hex: 0x8290B5))
        }
    }

    private var winnerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今夜いちばんの嘘つき")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(TPColor.caution)
                .padding(.top, 18)

            if let winner {
                winnerRow(winner)
            }
        }
    }

    private func winnerRow(_ winner: RankingShareCardData.Entry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            UsomiView(score: winner.score, unit: 46, animated: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(winner.name)
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(.white)
                Text(String(winner.score) + " ／100")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color(hex: 0x8290B5))
            }
        }
        .padding(.top, 6)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1).padding(.top, 16)
    }

    /// カードが縦に伸びすぎないよう、2位以下は上位4人までに絞る。
    private var rankList: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(data.entries.dropFirst().prefix(4))) { entry in
                rankRow(entry)
            }
        }
        .padding(.top, 14)
    }

    private func rankRow(_ entry: RankingShareCardData.Entry) -> some View {
        HStack(spacing: 8) {
            Text(String(entry.rank))
                .font(.system(size: 11, weight: .heavy).monospacedDigit())
                .foregroundStyle(Color(hex: 0x8290B5))
                .frame(width: 16, alignment: .leading)
            Text(entry.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: 0xA8B2D1))
            Spacer()
            Text(String(entry.score))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text(footerLine)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Color(hex: 0x8290B5))
            Spacer()
            Text("#TruthPulse")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(TPColor.deceitText)
        }
    }

    private var footerLine: String {
        let dateText = data.date.formatted(date: .abbreviated, time: .omitted)
        return dateText + " ・ " + String(data.entries.count) + "人"
    }
}

// MARK: - Renderer

enum RankingShareCardRenderer {
    /// @3x で書き出す。
    @MainActor
    static func render(_ data: RankingShareCardData) -> Image? {
        let renderer = ImageRenderer(content: RankingShareCardView(data: data))
        renderer.scale = 3
        renderer.isOpaque = true
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        Color.black
        RankingShareCardView(data: .init(
            groupID: UUID(),
            date: .now,
            entries: [
                .init(rank: 1, name: "ミク", score: 28),
                .init(rank: 2, name: "ケンタ", score: 44),
                .init(rank: 3, name: "ユウキ", score: 61),
                .init(rank: 4, name: "アオイ", score: 83)
            ]
        ))
    }
    .ignoresSafeArea()
}
