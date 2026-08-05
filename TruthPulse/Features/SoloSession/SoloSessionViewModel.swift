//
//  SoloSessionViewModel.swift
//  TruthPulse
//
//  Observation Framework（@Observable）による計測ステートマシン。
//

import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SoloSessionViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        /// 質問を入力して待機中
        case idle
        /// 指を置くのを待っている
        case awaitingTouch
        /// 計測中
        case sampling
        /// 指が離れて中断中（3 秒以内に戻せば再開）
        case interrupted
        /// 解析アニメーション中
        case analyzing
        /// 結果表示
        case result

        var isMeasuring: Bool { self == .sampling || self == .interrupted }
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var waveform: [Double] = Array(repeating: 0, count: SoloSessionViewModel.waveformCapacity)
    private(set) var pulse: Int = 0
    private(set) var microTremor: Double = 0
    private(set) var stress: Int = 0
    /// 計測中に表示するライブスコア（結果確定前は揺れ続ける）
    private(set) var liveScore: Int = 50
    private(set) var result: SessionResult?
    /// 心拍触覚 / 脈動アニメーションのトリガ。1 拍ごとに increment される。
    private(set) var heartbeatTick: Int = 0

    /// 任意入力。空でも計測できる（第三者が口頭で質問する想定）。
    var question: String = ""

    struct SessionResult: Equatable {
        let score: Int
        let confidence: Int
        let factors: [AnalysisFactor]
        var verdict: Verdict { Verdict(score: score) }
    }

    // MARK: - Derived

    var progress: Double {
        (elapsed / TPMetrics.samplingDuration).clamped(to: 0...1)
    }

    /// 例: "04.2秒 / 08.0秒"
    var samplingCounterText: String {
        String(format: "%04.1f秒 / %04.1f秒", elapsed, TPMetrics.samplingDuration)
    }

    /// 質問は任意なので、いつでも開始できる。
    var canStart: Bool { true }

    /// 画面に出す誠実度。結果確定後は固定値。
    var displayedScore: Int { result?.score ?? liveScore }

    // MARK: - Private

    private static let waveformCapacity = 120
    private var engine = BioSignalEngine()
    private var samplingTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var agitationSamples: [Double] = []
    private var liftCount = 0
    private var lastBeatIndex = -1
    /// 指の移動量から算出した「動揺量」0.0–1.0
    private var agitation: Double = 0
    private var persistedSamples: [BioSample] = []

    // MARK: - Intents

    func beginSession() {
        engine = BioSignalEngine()
        reset()
        phase = .awaitingTouch
    }

    /// タッチパッドに指が触れた。
    func fingerDown() {
        switch phase {
        case .awaitingTouch:
            startSampling()
        case .interrupted:
            interruptionTask?.cancel()
            interruptionTask = nil
            phase = .sampling
            TPAudio.shared.startLoop(.scan, volume: 0.55)
        default:
            break
        }
    }

    /// 指が動いた。移動量を動揺量に変換する（動かすほど疑わしくなる）。
    func fingerMoved(translation: CGSize) {
        guard phase == .sampling else { return }
        let dx = Double(translation.width)
        let dy = Double(translation.height)
        let magnitude = (dx * dx + dy * dy).squareRoot()
        // 24pt の移動で agitation 1.0 相当
        let instant = (magnitude / 24).clamped(to: 0...1)
        agitation = agitation * 0.85 + instant * 0.15
    }

    /// 指が離れた。3 秒以内に戻さなければ計測をやり直す。
    func fingerUp() {
        guard phase == .sampling else { return }
        liftCount += 1
        phase = .interrupted
        TPHaptics.warning()
        TPAudio.shared.stop(.scan)
        TPAudio.shared.play(.alert)
        interruptionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.abort()
        }
    }

    func abort() {
        TPAudio.shared.stopLoops()
        samplingTask?.cancel()
        interruptionTask?.cancel()
        reset()
        phase = .awaitingTouch
    }

    func resetToIdle() {
        TPAudio.shared.stopAll()
        samplingTask?.cancel()
        interruptionTask?.cancel()
        reset()
        phase = .idle
    }

    // MARK: - Sampling loop

    private func startSampling() {
        TPHaptics.prepare()
        TPAudio.shared.play(.start)
        TPAudio.shared.startLoop(.scan, volume: 0.55)
        phase = .sampling
        samplingTask = Task { [weak self] in
            await self?.runSamplingLoop()
        }
    }

    private func runSamplingLoop() async {
        // 経過時間はティックを積算して管理する。中断中は加算しないので、
        // 指を戻した位置から自然に再開できる。
        let step = TimeInterval(TPMetrics.sampleInterval.components.seconds)
            + TimeInterval(TPMetrics.sampleInterval.components.attoseconds) / 1e18

        while !Task.isCancelled {
            try? await Task.sleep(for: TPMetrics.sampleInterval)
            guard !Task.isCancelled else { return }

            // 中断中は時間を進めない
            guard phase == .sampling else {
                if phase == .interrupted { continue } else { return }
            }

            elapsed = min(elapsed + step, TPMetrics.samplingDuration)
            tick(at: elapsed)

            if elapsed >= TPMetrics.samplingDuration {
                await finish()
                return
            }
        }
    }

    private func tick(at t: TimeInterval) {
        // 指を止めているとゆっくり落ち着く
        agitation *= 0.985

        let value = engine.waveform(at: t, agitation: agitation)
        waveform.removeFirst()
        waveform.append(value)

        pulse = engine.pulse(at: t, agitation: agitation)
        microTremor = engine.microTremor(at: t, agitation: agitation)
        stress = engine.stress(at: t, agitation: agitation)
        agitationSamples.append(agitation)

        // ライブスコアは動揺量に追従してゆっくり動く
        let target = Double((1 - agitation) * 70 + 22)
        liveScore = Int((Double(liveScore) * 0.94 + target * 0.06).rounded())

        // 0.2 秒ごとに永続化用サンプルを間引き保存
        if Int(t * 5) > persistedSamples.count - 1 {
            persistedSamples.append(
                BioSample(offset: t, pulse: pulse, microTremor: microTremor, stress: Double(stress))
            )
        }

        // 心拍トリガ（触覚 + 脈動アニメーション）
        let beatIndex = Int(t / (60 / Double(max(pulse, 40))))
        if beatIndex != lastBeatIndex {
            lastBeatIndex = beatIndex
            heartbeatTick &+= 1
            TPHaptics.heartbeat()
            TPAudio.shared.play(.heartbeat, volume: 0.7)
        }
    }

    private func finish() async {
        phase = .analyzing
        TPAudio.shared.stop(.scan)
        TPAudio.shared.startLoop(.analyzing, volume: 0.6)
        try? await Task.sleep(for: .milliseconds(1_400))
        TPAudio.shared.stop(.analyzing)

        let synthesized = BioSignalEngine.synthesize(
            question: question,
            agitationSamples: agitationSamples,
            liftCount: liftCount
        )
        result = SessionResult(
            score: synthesized.score,
            confidence: synthesized.confidence,
            factors: synthesized.factors
        )
        liveScore = synthesized.score
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

    /// 結果を SwiftData に保存する。View 側から modelContext を受け取る。
    @discardableResult
    func persist(in context: ModelContext) -> ScanSession? {
        guard let result else { return nil }

        let session = ScanSession(
            mode: .solo,
            question: question,
            honestyScore: result.score,
            confidence: result.confidence,
            duration: TPMetrics.samplingDuration,
            factors: result.factors
        )
        context.insert(session)
        for sample in persistedSamples {
            sample.session = session
            context.insert(sample)
        }
        try? context.save()
        return session
    }

    // MARK: - Helpers

    private func reset() {
        elapsed = 0
        waveform = Array(repeating: 0, count: Self.waveformCapacity)
        pulse = 0
        microTremor = 0
        stress = 0
        liveScore = 50
        result = nil
        agitation = 0
        agitationSamples.removeAll()
        persistedSamples.removeAll()
        liftCount = 0
        lastBeatIndex = -1
        heartbeatTick = 0
    }
}
