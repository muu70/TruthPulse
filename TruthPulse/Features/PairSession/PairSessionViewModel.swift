//
//  PairSessionViewModel.swift
//  TruthPulse
//
//  ペア判定。2 人が 1 本ずつ指を置き、近づけながら 8 秒耐えます。
//
//  デュオ（顔認識）と狙いは同じですが、カメラを使わないぶん
//  暗い店内でも確実に動き、起動も速いのが利点です。
//

import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PairSessionViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        /// 質問を入力
        case setup
        /// 指を 2 本待っている
        case awaiting
        /// 計測中
        case measuring
        /// 指が離れた（戻せば続きから再開）
        case interrupted
        case analyzing
        case result
    }

    // MARK: - Tuning

    /// この距離以下で「触れ合っている」＝ 同調率 100%
    private static let contactDistance: CGFloat = 46
    /// 同調率 0% になる距離。パッド幅に対する比率で決める。
    private static let maxDistanceRatio: CGFloat = 0.72
    /// 計測を続けるのに必要な指の本数
    private static let requiredTouches = 2
    /// 指が離れてから中断扱いにするまでの猶予
    private static let graceDuration: TimeInterval = 2.5

    // MARK: - Observable state

    /// 任意入力。空でも計測できる。
    var question: String = ""

    private(set) var phase: Phase = .setup
    private(set) var touches: [CGPoint] = []
    private(set) var closeness: Double = 0
    private(set) var distancePt: Int = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var result: SessionResult?
    private(set) var heartbeatTick: Int = 0

    struct SessionResult: Equatable {
        let score: Int
        let confidence: Int
        let factors: [AnalysisFactor]
        var verdict: Verdict { Verdict(score: score) }
    }

    // MARK: - Derived

    var progress: Double {
        (elapsed / TPMetrics.pairSamplingDuration).clamped(to: 0...1)
    }

    var isContacting: Bool { closeness >= 0.995 }

    var guidance: (title: String, detail: String) {
        switch phase {
        case .setup:
            ("2人で1本ずつ", "指を置いて、近づけていきます")
        case .awaiting:
            switch touches.count {
            case 0: ("2人とも指を置いて", "パッドのどこでも構いません")
            case 1: ("あと1人", "相手の指を置いてください")
            default: ("そのまま計測に入ります", "")
            }
        case .measuring:
            if isContacting {
                ("そのまま、離さないで", "触れ合っています")
            } else if closeness > 0.6 {
                ("あと少し", "指を近づけて")
            } else {
                ("もっと近づけて", "遠いほど反応が乱れます")
            }
        case .interrupted:
            ("指が離れました", "戻すと続きから再開します")
        case .analyzing:
            ("解析中…", "2人の反応を照合しています")
        case .result:
            ("解析完了", "")
        }
    }

    // MARK: - Private

    private var loopTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var engine = BioSignalEngine()
    private var closenessSamples: [Double] = []
    private var agitationSamples: [Double] = []
    private var releaseCount = 0
    private var lastTouches: [CGPoint] = []
    private var agitation: Double = 0
    private var lastBeatIndex = -1
    private var padWidth: CGFloat = 360

    // MARK: - Intents

    func begin() {
        engine = BioSignalEngine()
        reset()
        phase = .awaiting
        TPAudio.shared.prepare()
    }

    func resetToSetup() {
        stopEverything()
        reset()
        result = nil
        phase = .setup
    }

    /// 結果を捨てて同じ質問でもう一度。
    func restart() {
        stopEverything()
        reset()
        result = nil
        phase = .awaiting
    }

    func updatePadWidth(_ width: CGFloat) {
        padWidth = max(120, width)
    }

    /// MultiTouchPad からの通知。
    func updateTouches(_ points: [CGPoint]) {
        touches = points
        updateCloseness()
        updateAgitation()

        switch phase {
        case .awaiting:
            if points.count >= Self.requiredTouches { startMeasuring() }

        case .measuring:
            if points.count < Self.requiredTouches { registerRelease() }

        case .interrupted:
            if points.count >= Self.requiredTouches { resume() }

        default:
            break
        }
    }

    // MARK: - Measurement

    private func startMeasuring() {
        phase = .measuring
        TPHaptics.prepare()
        TPAudio.shared.play(.start)
        TPAudio.shared.startLoop(.scan, volume: 0.55)
        startLoop()
    }

    private func resume() {
        graceTask?.cancel()
        graceTask = nil
        phase = .measuring
        TPAudio.shared.startLoop(.scan, volume: 0.55)
    }

    private func registerRelease() {
        releaseCount += 1
        phase = .interrupted
        TPHaptics.warning()
        TPAudio.shared.stop(.scan)
        TPAudio.shared.play(.alert)

        graceTask?.cancel()
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.graceDuration))
            guard !Task.isCancelled else { return }
            self?.abortToAwaiting()
        }
    }

    private func abortToAwaiting() {
        stopEverything()
        reset()
        phase = .awaiting
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    private func runLoop() async {
        let step = 0.05

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            // 中断中は時間を進めない（指を戻せば続きから）
            guard phase == .measuring else {
                if phase == .interrupted { continue } else { return }
            }

            elapsed = min(elapsed + step, TPMetrics.pairSamplingDuration)
            closenessSamples.append(closeness)
            agitationSamples.append(agitation)
            emitHeartbeat(at: elapsed)

            if elapsed >= TPMetrics.pairSamplingDuration {
                phase = .analyzing
                Task { await finish() }
                return
            }
        }
    }

    // MARK: - Signals

    /// 2 点の距離を 0.0（遠い）〜 1.0（触れ合っている）に変換する。
    private func updateCloseness() {
        guard touches.count >= 2 else {
            closeness = 0
            distancePt = 0
            return
        }

        let a = touches[0]
        let b = touches[1]
        let d = hypot(b.x - a.x, b.y - a.y)
        distancePt = Int(d.rounded())

        let maxD = padWidth * Self.maxDistanceRatio
        let span = max(1, maxD - Self.contactDistance)
        let normalized = (d - Self.contactDistance) / span
        closeness = Double(1 - normalized).clamped(to: 0...1)
    }

    /// 指の震え。近づけるほど照れて震えるので、そこそこ荒れた値が出る。
    private func updateAgitation() {
        defer { lastTouches = touches }

        guard touches.count == lastTouches.count, !touches.isEmpty else { return }

        let total = zip(touches, lastTouches)
            .reduce(0.0) { $0 + Double(hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y)) }
        let movement = total / Double(touches.count)

        // 8pt 動いたら agitation 1.0 相当
        let instant = (movement / 8).clamped(to: 0...1)
        agitation = agitation * 0.86 + instant * 0.14
    }

    private func emitHeartbeat(at t: TimeInterval) {
        // 近づくほど鼓動が速くなる演出
        let bpm = Double(engine.pulse(at: t, agitation: agitation)) + closeness * 18
        let interval = 60.0 / max(bpm, 40)
        let index = Int(t / max(interval, 0.3))
        if index != lastBeatIndex {
            lastBeatIndex = index
            heartbeatTick &+= 1
            TPHaptics.heartbeat()
            TPAudio.shared.play(.heartbeat, volume: 0.7)
        }
    }

    private func finish() async {
        TPAudio.shared.stop(.scan)
        TPAudio.shared.startLoop(.analyzing, volume: 0.6)
        try? await Task.sleep(for: .milliseconds(1_500))
        TPAudio.shared.stop(.analyzing)

        let synthesized = BioSignalEngine.synthesizePair(
            question: question,
            closenessSamples: closenessSamples,
            agitationSamples: agitationSamples,
            releaseCount: releaseCount
        )
        result = SessionResult(
            score: synthesized.score,
            confidence: synthesized.confidence,
            factors: synthesized.factors
        )
        phase = .result

        if Verdict(score: synthesized.score) == .truthful {
            TPHaptics.success()
            TPAudio.shared.play(.truth)
        } else {
            TPHaptics.warning()
            TPAudio.shared.play(.lie)
        }
    }

    // MARK: - Persistence

    @discardableResult
    func persist(in context: ModelContext) -> ScanSession? {
        guard let result else { return nil }

        let session = ScanSession(
            mode: .pair,
            question: question,
            honestyScore: result.score,
            confidence: result.confidence,
            duration: TPMetrics.pairSamplingDuration,
            factors: result.factors
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Helpers

    func stopEverything() {
        loopTask?.cancel()
        loopTask = nil
        graceTask?.cancel()
        graceTask = nil
        TPAudio.shared.stopLoops()
    }

    private func reset() {
        elapsed = 0
        closeness = 0
        distancePt = 0
        agitation = 0
        releaseCount = 0
        closenessSamples.removeAll()
        agitationSamples.removeAll()
        lastTouches = []
        lastBeatIndex = -1
        heartbeatTick = 0
    }
}
