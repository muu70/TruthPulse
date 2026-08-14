//
//  ScanSession.swift
//  TruthPulse
//
//  SwiftData 永続化モデル。1 回の「質問と計測」が 1 ScanSession。
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum ScanMode: String, Codable, CaseIterable, Sendable {
    case solo, duo, pair

    var displayName: String {
        switch self {
        case .solo: "ソロ・スキャン"
        case .duo: "デュオ・スキャン"
        case .pair: "ペア・スキャン"
        }
    }

    /// ダッシュボードのチップなど、狭い横幅で使う短縮名。
    var shortDisplayName: String {
        switch self {
        case .solo: "ソロ"
        case .duo: "デュオ"
        case .pair: "ペア"
        }
    }

    /// モード選択画面のアイコンと揃えている。
    var symbolName: String {
        switch self {
        case .solo: "person.fill"
        case .duo: "person.2.fill"
        case .pair: "hand.point.up.left.fill"
        }
    }
}

/// 判定は「本当」か「嘘」の 2 値。
/// 「もう一度計測してください」のような宙ぶらりんな結果は出しません。
enum Verdict: String, Codable, CaseIterable, Sendable {
    case truthful   // 50 以上
    case deceptive  // 50 未満

    init(score: Int) {
        self = score >= 50 ? .truthful : .deceptive
    }

    var symbolName: String {
        switch self {
        case .truthful: "checkmark.seal.fill"
        case .deceptive: "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .truthful: TPColor.truth
        case .deceptive: TPColor.deceit
        }
    }

    var textColor: Color {
        switch self {
        case .truthful: TPColor.truthText
        case .deceptive: TPColor.deceitText
        }
    }

    /// 短いラベル。履歴やシェアカードで使う。
    var shortLabel: String {
        switch self {
        case .truthful: "本当"
        case .deceptive: "嘘"
        }
    }

    var voiceOverLabel: String {
        switch self {
        case .truthful: "判定、本当"
        case .deceptive: "判定、嘘"
        }
    }
}

/// スコアの強さに応じた日本語表現。
/// 2 値の判定は保ちつつ、確信の度合いを言葉の強さで伝えます。
enum VerdictText {

    /// 結果画面の大見出し。
    static func headline(for score: Int) -> String {
        switch score {
        case 90...:   "まちがいなく\n本当"
        case 75..<90: "本当のことを\n言っています"
        case 60..<75: "おおむね\n本当"
        case 50..<60: "たぶん\n本当"
        case 35..<50: "たぶん\n嘘"
        case 20..<35: "嘘を\nついています"
        default:      "まっ赤な\n嘘"
        }
    }

    /// 1 行に収めたいとき（履歴・シェアカード）。
    static func inlineHeadline(for score: Int) -> String {
        headline(for: score).replacingOccurrences(of: "\n", with: "")
    }

    /// 見出しの下に添える一言。
    static func comment(for score: Int) -> String {
        switch score {
        case 90...:   "生体反応に乱れはまったくありません。"
        case 75..<90: "反応は落ち着いています。信じていいでしょう。"
        case 60..<75: "少し揺れましたが、大きな乱れはありません。"
        case 50..<60: "わずかに反応が出ましたが、許容範囲です。"
        case 35..<50: "反応に乱れがあります。少し怪しいですね。"
        case 20..<35: "はっきりとした乱れが出ました。"
        default:      "全項目で異常な反応。かなり動揺しています。"
        }
    }
}

/// 結果画面の内訳バー 1 本ぶん。
struct AnalysisFactor: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case microExpression, perspiration, pulseStability, voiceTension

        var title: String {
            switch self {
            case .microExpression: "マイクロ表情の揺らぎ"
            case .perspiration: "指先の発汗レベル"
            case .pulseStability: "心拍の安定性"
            case .voiceTension: "声紋テンション"
            }
        }
    }

    var id: Kind { kind }
    let kind: Kind
    /// 0.0–1.0
    let level: Double

    /// 色に依存しない補助ラベル。
    var levelLabel: String {
        switch level {
        case ..<0.35: "低"
        case ..<0.55: "やや低"
        case ..<0.75: "中"
        default: "高"
        }
    }
}

// MARK: - Models

@Model
final class ScanSession {
    #Index<ScanSession>([\.startedAt])

    var id: UUID = UUID()
    var startedAt: Date = Date()
    var modeRaw: String = ScanMode.solo.rawValue
    /// 旧バージョンの「相手の名前」。UI からは廃止済み。
    /// 既存データを壊さないため、プロパティ自体は残しています。
    var subjectName: String = ""
    /// 任意入力。空のこともある（第三者が口頭で質問する使い方）。
    var question: String = ""
    var honestyScore: Int = 0
    var verdictRaw: String = Verdict.truthful.rawValue
    var confidence: Int = 0
    var duration: TimeInterval = 0
    var factorsData: Data?
    /// 合コンモードで、同じ回のプレイをまとめる ID。ソロ等の単発計測では nil。
    var groupID: UUID?
    /// 合コンモード内での出番の順番（0 始まり）。
    var playerIndex: Int = 0
    /// 合コンモードでのプレイヤー名。空欄可（「プレイヤーN」等のフォールバックは呼び出し側で解決）。
    var playerName: String = ""

    @Relationship(deleteRule: .cascade, inverse: \BioSample.session)
    var samples: [BioSample] = []

    init(
        mode: ScanMode,
        question: String,
        honestyScore: Int,
        confidence: Int,
        duration: TimeInterval,
        factors: [AnalysisFactor],
        groupID: UUID? = nil,
        playerIndex: Int = 0,
        playerName: String = ""
    ) {
        self.id = UUID()
        self.startedAt = .now
        self.modeRaw = mode.rawValue
        self.question = question
        self.honestyScore = honestyScore
        self.verdictRaw = Verdict(score: honestyScore).rawValue
        self.confidence = confidence
        self.duration = duration
        self.factorsData = try? JSONEncoder().encode(factors)
        self.groupID = groupID
        self.playerIndex = playerIndex
        self.playerName = playerName
    }

    var mode: ScanMode { ScanMode(rawValue: modeRaw) ?? .solo }
    var verdict: Verdict { Verdict(rawValue: verdictRaw) ?? .truthful }

    /// スコア帯に応じた見出し・コメント。
    var headline: String { VerdictText.headline(for: honestyScore) }
    var inlineHeadline: String { VerdictText.inlineHeadline(for: honestyScore) }
    var comment: String { VerdictText.comment(for: honestyScore) }

    var factors: [AnalysisFactor] {
        guard let factorsData,
              let decoded = try? JSONDecoder().decode([AnalysisFactor].self, from: factorsData)
        else { return [] }
        return decoded
    }
}

/// 波形の再描画用に間引いて保存する生体サンプル。
@Model
final class BioSample {
    var offset: TimeInterval = 0
    var pulse: Int = 0
    var microTremor: Double = 0
    var stress: Double = 0
    var session: ScanSession?

    init(offset: TimeInterval, pulse: Int, microTremor: Double, stress: Double) {
        self.offset = offset
        self.pulse = pulse
        self.microTremor = microTremor
        self.stress = stress
    }
}

// MARK: - Container

enum TPModelContainer {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([ScanSession.self, BioSample.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("ModelContainer の生成に失敗しました: \(error)")
        }
    }()

    /// Preview 用のインメモリコンテナ（サンプルデータ入り）。
    @MainActor
    static let preview: ModelContainer = {
        let schema = Schema([ScanSession.self, BioSample.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        for sample in ScanSession.mocks {
            container.mainContext.insert(sample)
        }
        return container
    }()
}

extension ScanSession {
    static var mocks: [ScanSession] {
        [
            ScanSession(mode: .solo, question: "彼氏いない",
                        honestyScore: 31, confidence: 87, duration: 8,
                        factors: [
                            .init(kind: .microExpression, level: 0.82),
                            .init(kind: .perspiration, level: 0.56),
                            .init(kind: .pulseStability, level: 0.34),
                            .init(kind: .voiceTension, level: 0.64)
                        ]),
            ScanSession(mode: .solo, question: "年収は普通",
                        honestyScore: 88, confidence: 74, duration: 8,
                        factors: [
                            .init(kind: .microExpression, level: 0.22),
                            .init(kind: .perspiration, level: 0.30),
                            .init(kind: .pulseStability, level: 0.18),
                            .init(kind: .voiceTension, level: 0.25)
                        ]),
            ScanSession(mode: .duo, question: "",
                        honestyScore: 67, confidence: 61, duration: 8,
                        factors: [
                            .init(kind: .microExpression, level: 0.48),
                            .init(kind: .perspiration, level: 0.52),
                            .init(kind: .pulseStability, level: 0.41),
                            .init(kind: .voiceTension, level: 0.55)
                        ])
        ]
    }
}
