//
//  GokonModels.swift
//  TruthPulse
//
//  合コンモード専用のデータ型。SwiftData には保存しない一時的な値。
//

import Foundation

/// 合コンの参加者 1 人。
struct GokonPlayer: Identifiable, Hashable {
    let id = UUID()
    var name: String = ""

    /// 名前が空欄のときは出番順で「プレイヤーN」を名乗る。
    func displayName(at index: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "プレイヤー" + String(index + 1) : trimmed
    }
}

/// 1 人ぶんの出番の結果。途中経過リストとランキングの両方で使う。
struct GokonTurnResult: Identifiable, Hashable {
    let id = UUID()
    let playerIndex: Int
    let playerName: String
    let question: String
    let honestyScore: Int
    let confidence: Int
    let factors: [AnalysisFactor]

    var verdict: Verdict { Verdict(score: honestyScore) }
}
