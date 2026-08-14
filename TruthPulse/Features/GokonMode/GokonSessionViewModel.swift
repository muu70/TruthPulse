//
//  GokonSessionViewModel.swift
//  TruthPulse
//
//  合コンモードのステートマシン。
//
//  2 階層で状態を持つ: 外側の `Stage` がどの画面か、内側の `TurnPhase` が
//  出番中の計測サブステート（SoloSessionViewModel.Phase を踏襲）。
//  計測ロジック自体はソロと同じ仕組みを使うが、複数人ぶん繰り返す都合上
//  共通の基底クラスにはせず、このクラス内に複製している
//  （Solo / Pair も互いに独立実装しており、それに倣う）。
//

import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GokonSessionViewModel {

    // MARK: - Stage

    enum Stage: Equatable {
        /// メンバー設定
        case setup
        /// 出番中（お題選び〜計測）
        case turn(TurnPhase)
        /// 直前の結果 + 途中経過
        case leaderboard
        /// 全員終了、ランキング発表
        case finalReveal
        /// 罰ゲームルーレット
        case penalty
    }

    enum TurnPhase: Equatable {
        /// お題を選んでいる
        case pickingQuestion
        /// 指を置くのを待っている
        case awaitingTouch
        /// 計測中
        case sampling
        /// 指が離れて中断中
        case interrupted
        /// 解析アニメーション中
        case analyzing

        var isMeasuring: Bool { self == .sampling || self == .interrupted }
    }

    // MARK: - Tuning

    private static let minPlayers = 2
    private static let maxPlayers = 8
    private static let waveformCapacity = 120

    // MARK: - Setup state（直接バインディングする入力値）

    var players: [GokonPlayer] = [GokonPlayer(), GokonPlayer()]
    var shuffleOrder = false

    // MARK: - Run state

    private(set) var groupID: UUID?
    private(set) var currentPlayerIndex = 0
    private(set) var stage: Stage = .setup
    private(set) var results: [GokonTurnResult] = []
    private(set) var currentPenalty: GokonPenalty?

    // MARK: - Per-turn state

    private(set) var selectedCategory: GokonQuestionCategory = .exploratory
    var question: String = ""
    private(set) var elapsed: TimeInterval = 0
    private(set) var waveform: [Double] = Array(repeating: 0, count: GokonSessionViewModel.waveformCapacity)
    private(set) var pulse: Int = 0
    private(set) var microTremor: Double = 0
    private(set) var stress: Int = 0
    private(set) var liveScore: Int = 50
    private(set) var heartbeatTick: Int = 0
    private(set) var lastResult: GokonTurnResult?

    // MARK: - Private

    private var engine = BioSignalEngine()
    private var samplingTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var agitationSamples: [Double] = []
    private var usedQuestionIDs: Set<Int> = []
    private var liftCount = 0
    private var lastBeatIndex = -1
    private var agitation: Double = 0
    private var persistedSamples: [BioSample] = []

    // MARK: - Derived

    var currentPlayer: GokonPlayer? {
        players.indices.contains(currentPlayerIndex) ? players[currentPlayerIndex] : nil
    }

    var currentPlayerDisplayName: String {
        currentPlayer?.displayName(at: currentPlayerIndex) ?? ""
    }

    /// 例: "2 / 4人目"
    var progressText: String {
        String(currentPlayerIndex + 1) + " / " + String(players.count) + "人目"
    }

    var isLastPlayer: Bool { currentPlayerIndex >= players.count - 1 }

    /// 誠実度の低い順（＝嘘つき順）に並べたランキング。
    var rankedResults: [GokonTurnResult] { results.sorted { $0.honestyScore < $1.honestyScore } }

    var progress: Double { (elapsed / TPMetrics.samplingDuration).clamped(to: 0...1) }

    var samplingCounterText: String {
        String(format: "%04.1f秒 / %04.1f秒", elapsed, TPMetrics.samplingDuration)
    }

    var canStartGame: Bool {
        players.count >= Self.minPlayers && players.count <= Self.maxPlayers
    }

    var isMinPlayerCount: Bool { players.count <= Self.minPlayers }
    var isMaxPlayerCount: Bool { players.count >= Self.maxPlayers }

    private var turnPhase: TurnPhase? {
        if case .turn(let phase) = stage { return phase }
        return nil
    }

    // MARK: - Setup intents

    func addPlayer() {
        guard players.count < Self.maxPlayers else { return }
        players.append(GokonPlayer())
    }

    func removePlayer(at index: Int) {
        guard players.count > Self.minPlayers, players.indices.contains(index) else { return }
        players.remove(at: index)
    }

    /// 人数チップ（2 / 4 / 6 / 8）で使う。既存の名前はできるだけ保持する。
    func setPlayerCount(_ count: Int) {
        let clamped = count.clamped(to: Self.minPlayers...Self.maxPlayers)
        if clamped > players.count {
            players.append(contentsOf: (players.count..<clamped).map { _ in GokonPlayer() })
        } else if clamped < players.count {
            players.removeLast(players.count - clamped)
        }
    }

    // MARK: - Flow intents

    func startGame() {
        guard canStartGame else { return }
        if shuffleOrder { players.shuffle() }
        groupID = UUID()
        currentPlayerIndex = 0
        results = []
        beginTurn()
    }

    private func beginTurn() {
        engine = BioSignalEngine()
        resetSamplingState()
        usedQuestionIDs.removeAll()
        selectedCategory = .exploratory
        rerollQuestion()
        stage = .turn(.pickingQuestion)
    }

    func selectCategory(_ category: GokonQuestionCategory) {
        selectedCategory = category
        rerollQuestion()
    }

    /// 使っていない問題から選ぶ。カテゴリを使い切ったら使用済みも許容する。
    func rerollQuestion() {
        let pool = GokonQuestionDeck.questions(in: selectedCategory)
        let unused = pool.filter { !usedQuestionIDs.contains($0.id) }
        let candidates = unused.isEmpty ? pool : unused
        guard let picked = candidates.randomElement() else { return }
        usedQuestionIDs.insert(picked.id)
        question = picked.text
    }

    func beginTurnScan() {
        guard turnPhase == .pickingQuestion, !question.isEmpty else { return }
        stage = .turn(.awaitingTouch)
    }

    // MARK: - Measuring（SoloSessionViewModel と同じ仕組みをターンごとに実行）

    func fingerDown() {
        switch turnPhase {
        case .awaitingTouch:
            startSampling()
        case .interrupted:
            interruptionTask?.cancel()
            interruptionTask = nil
            stage = .turn(.sampling)
            TPAudio.shared.startLoop(.scan, volume: 0.55)
        default:
            break
        }
    }

    func fingerMoved(translation: CGSize) {
        guard turnPhase == .sampling else { return }
        let dx = Double(translation.width)
        let dy = Double(translation.height)
        let magnitude = (dx * dx + dy * dy).squareRoot()
        let instant = (magnitude / 24).clamped(to: 0...1)
        agitation = agitation * 0.85 + instant * 0.15
    }

    func fingerUp() {
        guard turnPhase == .sampling else { return }
        liftCount += 1
        stage = .turn(.interrupted)
        TPHaptics.warning()
        TPAudio.shared.stop(.scan)
        TPAudio.shared.play(.alert)
        interruptionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.abortTurn()
        }
    }

    private func abortTurn() {
        TPAudio.shared.stopLoops()
        samplingTask?.cancel()
        interruptionTask?.cancel()
        resetSamplingState()
        stage = .turn(.awaitingTouch)
    }

    private func startSampling() {
        TPHaptics.prepare()
        TPAudio.shared.play(.start)
        TPAudio.shared.startLoop(.scan, volume: 0.55)
        stage = .turn(.sampling)
        samplingTask = Task { [weak self] in
            await self?.runSamplingLoop()
        }
    }

    private func runSamplingLoop() async {
        let step = TimeInterval(TPMetrics.sampleInterval.components.seconds)
            + TimeInterval(TPMetrics.sampleInterval.components.attoseconds) / 1e18

        while !Task.isCancelled {
            try? await Task.sleep(for: TPMetrics.sampleInterval)
            guard !Task.isCancelled else { return }

            // 中断中は時間を進めない
            guard turnPhase == .sampling else {
                if turnPhase == .interrupted { continue } else { return }
            }

            elapsed = min(elapsed + step, TPMetrics.samplingDuration)
            tick(at: elapsed)

            if elapsed >= TPMetrics.samplingDuration {
                await finishTurn()
                return
            }
        }
    }

    private func tick(at t: TimeInterval) {
        agitation *= 0.985

        let value = engine.waveform(at: t, agitation: agitation)
        waveform.removeFirst()
        waveform.append(value)

        pulse = engine.pulse(at: t, agitation: agitation)
        microTremor = engine.microTremor(at: t, agitation: agitation)
        stress = engine.stress(at: t, agitation: agitation)
        agitationSamples.append(agitation)

        let target = Double((1 - agitation) * 70 + 22)
        liveScore = Int((Double(liveScore) * 0.94 + target * 0.06).rounded())

        if Int(t * 5) > persistedSamples.count - 1 {
            persistedSamples.append(
                BioSample(offset: t, pulse: pulse, microTremor: microTremor, stress: Double(stress))
            )
        }

        let beatIndex = Int(t / (60 / Double(max(pulse, 40))))
        if beatIndex != lastBeatIndex {
            lastBeatIndex = beatIndex
            heartbeatTick &+= 1
            TPHaptics.heartbeat()
            TPAudio.shared.play(.heartbeat, volume: 0.7)
        }
    }

    private func finishTurn() async {
        stage = .turn(.analyzing)
        TPAudio.shared.stop(.scan)
        TPAudio.shared.startLoop(.analyzing, volume: 0.6)
        try? await Task.sleep(for: .milliseconds(1_400))
        TPAudio.shared.stop(.analyzing)

        let synthesized = BioSignalEngine.synthesize(
            question: question,
            agitationSamples: agitationSamples,
            liftCount: liftCount
        )

        let result = GokonTurnResult(
            playerIndex: currentPlayerIndex,
            playerName: currentPlayerDisplayName,
            question: question,
            honestyScore: synthesized.score,
            confidence: synthesized.confidence,
            factors: synthesized.factors
        )
        results.append(result)
        lastResult = result
        liveScore = synthesized.score

        if result.verdict == .truthful {
            TPHaptics.success()
            TPAudio.shared.play(.truth)
        } else {
            TPHaptics.warning()
            TPAudio.shared.play(.lie)
        }

        stage = .leaderboard
    }

    // MARK: - Persistence

    /// ターンが終わるたびに即保存する。まとめて保存にしないのは、
    /// 途中でアプリを閉じても既に終えた人の記録が消えないようにするため。
    func persistLastTurn(in context: ModelContext) {
        guard let result = lastResult, let groupID else { return }

        let session = ScanSession(
            mode: .solo,
            question: result.question,
            honestyScore: result.honestyScore,
            confidence: result.confidence,
            duration: TPMetrics.samplingDuration,
            factors: result.factors,
            groupID: groupID,
            playerIndex: result.playerIndex,
            playerName: result.playerName
        )
        context.insert(session)
        for sample in persistedSamples {
            sample.session = session
            context.insert(sample)
        }
        try? context.save()
    }

    // MARK: - Advance

    func advanceToNextPlayer() {
        currentPlayerIndex += 1
        if currentPlayerIndex < players.count {
            beginTurn()
        } else {
            stage = .finalReveal
        }
    }

    // MARK: - Penalty

    func startPenaltyRoulette() {
        stage = .penalty
    }

    @discardableResult
    func spinPenalty() -> GokonPenalty {
        // 直前と同じものが連続で出にくいようにする
        let candidates = currentPenalty.map { penalty in
            GokonPenaltyDeck.all.filter { $0.id != penalty.id }
        } ?? GokonPenaltyDeck.all
        let picked = candidates.randomElement() ?? GokonPenaltyDeck.all[0]
        currentPenalty = picked
        return picked
    }

    // MARK: - Reset

    func restart() {
        TPAudio.shared.stopAll()
        samplingTask?.cancel()
        interruptionTask?.cancel()
        players = [GokonPlayer(), GokonPlayer()]
        shuffleOrder = false
        groupID = nil
        currentPlayerIndex = 0
        results = []
        currentPenalty = nil
        resetSamplingState()
        stage = .setup
    }

    private func resetSamplingState() {
        elapsed = 0
        waveform = Array(repeating: 0, count: Self.waveformCapacity)
        pulse = 0
        microTremor = 0
        stress = 0
        liveScore = 50
        agitation = 0
        agitationSamples.removeAll()
        persistedSamples.removeAll()
        liftCount = 0
        lastBeatIndex = -1
        heartbeatTick = 0
    }
}
