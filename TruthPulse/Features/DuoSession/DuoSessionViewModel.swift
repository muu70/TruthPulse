//
//  DuoSessionViewModel.swift
//  TruthPulse
//
//  2 人の顔の距離を SYNC 値に変換し、十分に近づいたらスキャンを始める
//  ステートマシン。ソロと同じ BioSignalEngine で判定を合成します。
//

import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DuoSessionViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        /// 質問を入力（カメラ未起動）
        case setup
        /// 顔を探している（0〜1 人）
        case searching
        /// 2 人検出。まだ遠い
        case aligning
        /// 十分近い。ロック確定までのカウントダウン中
        case locking
        /// スキャン中
        case sampling
        /// 離れてスキャン中断
        case lost
        case analyzing
        case result

        var isScanning: Bool { self == .sampling || self == .lost }
    }

    // MARK: - Tuning

    // 距離は「顔の幅の何個ぶん離れているか」で測ります。
    // 正規化座標をそのまま使うと、カメラの画角や立ち位置で基準が変わってしまうため。
    // 頬がくっつくと約 1.0、肩幅ぶん離れると 2.0 前後になります。

    /// この比率以下で「密着」＝ 同期率 100%
    private static let minGap: Double = 1.05
    /// この比率以上で 同期率 0%
    private static let maxGap: Double = 2.30
    /// スキャン開始に必要な同期率
    private static let lockThreshold: Double = 0.72
    /// スキャン継続に必要な同期率（ヒステリシス）
    private static let releaseThreshold: Double = 0.52
    /// ロック確定までの保持時間
    private static let lockHoldDuration: TimeInterval = 1.0

    // MARK: - Observable state

    let tracker: FaceTrackingService

    /// 任意入力。空でも計測できる。
    var question: String = ""

    private(set) var phase: Phase = .setup
    private(set) var sync: Double = 0
    private(set) var distanceCM: Int = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var lockProgress: Double = 0
    private(set) var result: SessionResult?
    private(set) var heartbeatTick: Int = 0

    struct SessionResult: Equatable {
        let score: Int
        let confidence: Int
        let factors: [AnalysisFactor]
        var verdict: Verdict { Verdict(score: score) }
    }

    // MARK: - Derived

    var faces: [DetectedFace] { tracker.faces }

    var progress: Double {
        (elapsed / TPMetrics.duoSamplingDuration).clamped(to: 0...1)
    }

    /// 質問は任意なので、いつでも開始できる。
    var canStart: Bool { true }

    var guidance: (title: String, detail: String) {
        switch phase {
        case .setup:
            ("2人でスキャン", "質問は任意です。そのまま始められます")
        case .searching:
            ("2人の顔をフレームに入れて", "並んで、カメラに正面を向けてください")
        case .aligning:
            ("もう少しだけ、顔を近づけて", "枠が緑になったらスキャンが始まります")
        case .locking:
            ("そのまま動かないで", "ロックしています…")
        case .sampling:
            ("スキャン中", "顔を離さないでください")
        case .lost:
            ("離れました", "もう一度近づけると再開します")
        case .analyzing:
            ("解析中…", "2人の生体反応を照合しています")
        case .result:
            ("解析完了", "")
        }
    }

    // MARK: - Private

    private var loopTask: Task<Void, Never>?
    private var engine = BioSignalEngine()
    private var agitationSamples: [Double] = []
    private var lostCount = 0
    private var lockHeld: TimeInterval = 0
    private var lastCenters: [CGPoint] = []
    private var agitation: Double = 0
    private var lastBeatIndex = -1

    init(tracker: FaceTrackingService = FaceTrackingService()) {
        self.tracker = tracker
    }

    // MARK: - Intents

    func startCamera() async {
        engine = BioSignalEngine()
        resetMeasurement()
        phase = .searching
        await tracker.start()
        startLoop()
    }

    func stopCamera() {
        loopTask?.cancel()
        loopTask = nil
        tracker.stop()
    }

    func resetToSetup() {
        stopCamera()
        resetMeasurement()
        result = nil
        phase = .setup
    }

    /// 結果を捨てて同じ質問でもう一度。
    func rescan() async {
        resetMeasurement()
        result = nil
        phase = .searching
        if !tracker.isRunning { await tracker.start() }
        startLoop()
    }

    // MARK: - Loop

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
            guard phase != .analyzing, phase != .result else { return }

            updateSync()
            updateAgitation()
            advance(by: step)
        }
    }

    /// 顔の中心間距離から SYNC と擬似的な距離表示を作る。
    private func updateSync() {
        let detected = tracker.faces
        guard detected.count >= 2 else {
            sync = 0
            distanceCM = 0
            if phase == .aligning || phase == .locking { phase = .searching }
            if phase == .sampling { registerLoss() }
            return
        }

        let a = detected[0].center
        let b = detected[1].center
        let pixelGap = Double(hypot(b.x - a.x, b.y - a.y))

        // 顔の平均幅で割る＝「顔いくつぶん離れているか」。
        // カメラとの距離が変わっても基準がぶれない。
        let avgWidth = (Double(detected[0].bounds.width) + Double(detected[1].bounds.width)) / 2
        let gap = avgWidth > 0.01 ? pixelGap / avgWidth : Self.maxGap

        let normalized = (gap - Self.minGap) / (Self.maxGap - Self.minGap)
        sync = (1 - normalized).clamped(to: 0...1)
        // 実測ではなく、見せるための換算値（頬がつくと 1cm 前後）
        distanceCM = max(1, Int(((gap - 0.95) * 26).rounded()))
    }

    private func updateAgitation() {
        let centers = tracker.faces.map(\.center)
        defer { lastCenters = centers }

        guard centers.count == lastCenters.count, !centers.isEmpty else { return }

        let total = zip(centers, lastCenters)
            .reduce(0.0) { $0 + Double(hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y)) }
        let movement = total / Double(centers.count)

        // 正規化座標で 0.03 動いたら agitation 1.0 相当
        let instant = (movement / 0.03).clamped(to: 0...1)
        agitation = agitation * 0.88 + instant * 0.12
    }

    private func advance(by step: TimeInterval) {
        switch phase {
        case .searching:
            if tracker.faces.count >= 2 { phase = .aligning }

        case .aligning:
            if sync >= Self.lockThreshold {
                lockHeld = 0
                phase = .locking
            }

        case .locking:
            if sync < Self.releaseThreshold {
                lockHeld = 0
                lockProgress = 0
                phase = .aligning
                return
            }
            lockHeld += step
            lockProgress = (lockHeld / Self.lockHoldDuration).clamped(to: 0...1)
            if lockHeld >= Self.lockHoldDuration {
                lockProgress = 1
                phase = .sampling
                TPHaptics.prepare()
                TPHaptics.select()
            }

        case .sampling:
            guard sync >= Self.releaseThreshold else {
                registerLoss()
                return
            }
            elapsed = min(elapsed + step, TPMetrics.duoSamplingDuration)
            agitationSamples.append(agitation)
            emitHeartbeat(at: elapsed)

            if elapsed >= TPMetrics.duoSamplingDuration {
                Task { await finish() }
                phase = .analyzing
            }

        case .lost:
            // 近づけ直せば同じ位置から再開
            if sync >= Self.lockThreshold { phase = .sampling }

        default:
            break
        }
    }

    private func registerLoss() {
        guard phase == .sampling else { return }
        lostCount += 1
        phase = .lost
        TPHaptics.warning()
    }

    /// 2 人ぶんの心拍が少しずれて重なるイメージで、やや速めに打つ。
    private func emitHeartbeat(at t: TimeInterval) {
        let interval = 60.0 / Double(engine.pulse(at: t, agitation: agitation))
        let index = Int(t / max(interval, 0.3))
        if index != lastBeatIndex {
            lastBeatIndex = index
            heartbeatTick &+= 1
            TPHaptics.heartbeat()
        }
    }

    private func finish() async {
        try? await Task.sleep(for: .milliseconds(1_600))

        let synthesized = BioSignalEngine.synthesize(
            question: question,
            agitationSamples: agitationSamples,
            liftCount: lostCount
        )
        result = SessionResult(
            score: synthesized.score,
            confidence: synthesized.confidence,
            factors: synthesized.factors
        )
        phase = .result
        stopCamera()

        if Verdict(score: synthesized.score) == .truthful {
            TPHaptics.success()
        } else {
            TPHaptics.warning()
        }
    }

    // MARK: - Persistence

    @discardableResult
    func persist(in context: ModelContext) -> ScanSession? {
        guard let result else { return nil }

        let session = ScanSession(
            mode: .duo,
            question: question,
            honestyScore: result.score,
            confidence: result.confidence,
            duration: TPMetrics.duoSamplingDuration,
            factors: result.factors
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Helpers

    private func resetMeasurement() {
        sync = 0
        distanceCM = 0
        elapsed = 0
        lockProgress = 0
        lockHeld = 0
        lostCount = 0
        agitation = 0
        agitationSamples.removeAll()
        lastCenters = []
        lastBeatIndex = -1
        heartbeatTick = 0
    }
}
