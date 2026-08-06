//
//  BioSignalEngine.swift
//  TruthPulse
//
//  「それらしい」生体信号を合成するエンジン。
//  実際の生体計測は一切行いません — 複数の正弦波 + ノイズ + 指の動きへの反応で
//  “計器が生きている” 見た目だけを作ります。
//

import Foundation

struct BioSignalEngine: Sendable {

    /// セッションごとに固定される個性。同じセッション中は波形の癖が一貫する。
    private let seed: Double
    private let baselinePulse: Double
    private let breathPeriod: Double

    init(seed: UInt64 = .random(in: 0...UInt64.max)) {
        var generator = SplitMix64(state: seed)
        self.seed = Double(generator.next() % 1_000) / 1_000
        self.baselinePulse = 72 + Double(generator.next() % 22)   // 72–93 bpm
        self.breathPeriod = 3.4 + Double(generator.next() % 12) / 10 // 3.4–4.5s
    }

    /// 波形 1 点。-1.0 ... 1.0
    /// 心拍の鋭いスパイク + 呼吸によるうねり + 微細ノイズ。
    func waveform(at t: TimeInterval, agitation: Double) -> Double {
        let beatPhase = (t / heartbeatInterval).truncatingRemainder(dividingBy: 1)

        // QRS 波っぽい非対称スパイク
        let spike: Double
        switch beatPhase {
        case 0.00..<0.06: spike = sin(beatPhase / 0.06 * .pi) * 0.95
        case 0.06..<0.14: spike = -sin((beatPhase - 0.06) / 0.08 * .pi) * 0.35
        case 0.30..<0.45: spike = sin((beatPhase - 0.30) / 0.15 * .pi) * 0.22
        default: spike = 0
        }

        let breath = sin(t / breathPeriod * 2 * .pi) * 0.12
        let noise = (sin(t * 37.1 + seed * 10) + sin(t * 61.7 + seed * 20)) * 0.035
        let jitter = agitation * 0.25 * sin(t * 23.3 + seed * 30)

        return (spike + breath + noise + jitter).clamped(to: -1...1)
    }

    /// 表示用 BPM。緊張が高いほど上がる。
    func pulse(at t: TimeInterval, agitation: Double) -> Int {
        let drift = sin(t / 5.2 + seed * 6) * 3
        return Int((baselinePulse + drift + agitation * 26).rounded())
    }

    /// マイクロトレモア Δ（0.0–2.0 想定）
    func microTremor(at t: TimeInterval, agitation: Double) -> Double {
        let base = 0.28 + abs(sin(t / 2.7 + seed * 3)) * 0.22
        return ((base + agitation * 0.9) * 100).rounded() / 100
    }

    /// ストレス率（0–100）
    func stress(at t: TimeInterval, agitation: Double) -> Int {
        let base = 24 + sin(t / 4.1 + seed * 9) * 8
        return Int((base + agitation * 48).clamped(to: 0...99).rounded())
    }

    private var heartbeatInterval: Double { 60 / baselinePulse }
}

// MARK: - Verdict synthesis

extension BioSignalEngine {

    /// 計測中に溜まった「動揺量」から最終スコアを合成する。
    ///
    /// - 指が揺れた／離れた回数が多いほどスコアは下がる
    /// - 質問文のハッシュを混ぜることで、同じ質問なら似た傾向になる（＝“再現性がある機械”に見える）
    /// - 最後に ±6 のゆらぎを足して完全な予測を防ぐ
    static func synthesize(
        question: String,
        agitationSamples: [Double],
        liftCount: Int
    ) -> (score: Int, confidence: Int, factors: [AnalysisFactor]) {

        let meanAgitation = agitationSamples.isEmpty
            ? 0.25
            : agitationSamples.reduce(0, +) / Double(agitationSamples.count)
        let peakAgitation = agitationSamples.max() ?? 0.3

        // 質問が入力されていれば、その文字列から安定したバイアスを作る
        // （同じ質問なら似た傾向 ＝ 再現性のある機械に見える）。
        // 未入力なら毎回ランダム。第三者が口頭で質問する使い方を想定。
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let questionBias: Double = normalized.isEmpty
            ? Double.random(in: 0...1)
            : Double(fnv1a(normalized) % 100) / 100

        // 動揺 60% / 質問バイアス 30% / 指離し 10%
        let suspicion = (meanAgitation * 0.45
                         + peakAgitation * 0.15
                         + questionBias * 0.30
                         + min(Double(liftCount) * 0.05, 0.10))
            .clamped(to: 0...1)

        let noise = Double.random(in: -0.06...0.06)
        let score = Int(((1 - suspicion + noise) * 100).clamped(to: 3...97).rounded())

        // 端に振れているほど「自信あり」に見せる
        let confidence = Int((58 + abs(50 - Double(score)) * 0.72).rounded())

        let factors: [AnalysisFactor] = [
            .init(kind: .microExpression, level: (suspicion * 1.05 + 0.04).clamped(to: 0.05...0.97)),
            .init(kind: .perspiration, level: (meanAgitation * 1.3 + questionBias * 0.2).clamped(to: 0.05...0.95)),
            .init(kind: .pulseStability, level: (1 - suspicion * 0.85).clamped(to: 0.08...0.95)),
            .init(kind: .voiceTension, level: (peakAgitation * 0.8 + questionBias * 0.25).clamped(to: 0.05...0.95))
        ]

        return (score, confidence, factors)
    }
}

// MARK: - Pair synthesis

extension BioSignalEngine {

    /// ペア判定（2 人が指を近づけながら答える）用の合成。
    ///
    /// ソロ・デュオと違い、**指の近さ**を主成分にしています。
    /// 近づけて静止していられた 2 人ほど高スコアになる、という建て付けです。
    /// 実際には近づけるほど照れて震えるので、そこそこ荒れた値が出ます。
    ///
    /// - closeness: 0.0（離れている）〜 1.0（触れ合っている）
    static func synthesizePair(
        question: String,
        closenessSamples: [Double],
        agitationSamples: [Double],
        releaseCount: Int
    ) -> (score: Int, confidence: Int, factors: [AnalysisFactor]) {

        let meanCloseness = closenessSamples.isEmpty
            ? 0.4
            : closenessSamples.reduce(0, +) / Double(closenessSamples.count)
        let meanAgitation = agitationSamples.isEmpty
            ? 0.25
            : agitationSamples.reduce(0, +) / Double(agitationSamples.count)
        let peakAgitation = agitationSamples.max() ?? 0.3

        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let questionBias: Double = normalized.isEmpty
            ? Double.random(in: 0...1)
            : Double(fnv1a(normalized) % 100) / 100

        // 近さ 50% / 震え 30% / 質問バイアス 20%
        let suspicion = ((1 - meanCloseness) * 0.50
                         + meanAgitation * 0.20
                         + peakAgitation * 0.10
                         + questionBias * 0.20
                         + min(Double(releaseCount) * 0.04, 0.08))
            .clamped(to: 0...1)

        let noise = Double.random(in: -0.05...0.05)
        let score = Int(((1 - suspicion + noise) * 100).clamped(to: 3...97).rounded())
        let confidence = Int((60 + abs(50 - Double(score)) * 0.70).rounded())

        let factors: [AnalysisFactor] = [
            .init(kind: .microExpression,
                  level: (suspicion * 1.02 + 0.05).clamped(to: 0.05...0.97)),
            .init(kind: .perspiration,
                  level: (meanAgitation * 1.2 + (1 - meanCloseness) * 0.35).clamped(to: 0.05...0.95)),
            .init(kind: .pulseStability,
                  level: (1 - suspicion * 0.80).clamped(to: 0.08...0.95)),
            .init(kind: .voiceTension,
                  level: (peakAgitation * 0.7 + questionBias * 0.3).clamped(to: 0.05...0.95))
        ]

        return (score, confidence, factors)
    }
}

// MARK: - Utilities

/// 起動をまたいで安定するハッシュ。同じ質問なら同じバイアスになる。
private func fnv1a(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

/// 再現性のある軽量 PRNG。
private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
