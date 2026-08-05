//
//  TPAudio.swift
//  TruthPulse
//
//  効果音。音源は tools/generate_sounds.py で合成した WAV を同梱しています。
//
//  オーディオセッションは `.ambient` を使います。
//  - サイレントスイッチに従う（マナーモード中は鳴らない）
//  - 他アプリの音楽を止めない（会場で音楽がかかっていても共存できる）
//

import AVFoundation
import Foundation
import SwiftUI

// MARK: - Sound

enum TPSound: String, CaseIterable {
    case select
    case start
    case heartbeat
    case scan        // ループ
    case lock
    case alert
    case analyzing   // ループ
    case truth
    case lie

    var loops: Bool { self == .scan || self == .analyzing }

    /// 同時に鳴りうる数。心拍は連打されるので多めに確保する。
    var voices: Int {
        switch self {
        case .heartbeat: 3
        case .select: 2
        default: 1
        }
    }
}

// MARK: - Sound set

enum TPSoundSet: String, CaseIterable, Identifiable {
    case variety
    case clinical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .variety: "バラエティ"
        case .clinical: "計測器"
        }
    }

    var summary: String {
        switch self {
        case .variety: "ピンポーン / ブブー。周りを巻き込む"
        case .clinical: "無機質な電子音だけ"
        }
    }

    var symbolName: String {
        switch self {
        case .variety: "party.popper.fill"
        case .clinical: "waveform.path.ecg"
        }
    }

    func fileName(for sound: TPSound) -> String {
        "sfx_" + rawValue + "_" + sound.rawValue
    }
}

// MARK: - Settings

/// 音の設定。View からは `@AppStorage` 経由でも読めるようキーを公開する。
enum TPAudioSettings {
    static let mutedKey = "tp.audio.muted"
    static let setKey = "tp.audio.set"
}

// MARK: - Player

@MainActor
final class TPAudio {

    static let shared = TPAudio()

    private var players: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]
    private var loaded: TPSoundSet?
    private var sessionActivated = false

    private init() {}

    // MARK: Settings

    var isMuted: Bool {
        UserDefaults.standard.bool(forKey: TPAudioSettings.mutedKey)
    }

    var soundSet: TPSoundSet {
        let raw = UserDefaults.standard.string(forKey: TPAudioSettings.setKey) ?? ""
        return TPSoundSet(rawValue: raw) ?? .variety
    }

    // MARK: Lifecycle

    /// 計測を始める直前に呼ぶ。ファイル読み込みとセッション有効化をまとめて済ませる。
    func prepare() {
        activateSessionIfNeeded()
        let set = soundSet
        guard loaded != set else { return }
        stopAll()
        players.removeAll()
        nextVoice.removeAll()

        for sound in TPSound.allCases {
            let name = set.fileName(for: sound)
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
                continue
            }
            var voices: [AVAudioPlayer] = []
            for _ in 0..<sound.voices {
                guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.numberOfLoops = sound.loops ? -1 : 0
                player.prepareToPlay()
                voices.append(player)
            }
            if !voices.isEmpty {
                players[sound.rawValue] = voices
            }
        }
        loaded = set
    }

    private func activateSessionIfNeeded() {
        guard !sessionActivated else { return }
        let session = AVAudioSession.sharedInstance()
        // .ambient = サイレントスイッチに従い、他アプリの音楽も止めない
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        sessionActivated = true
    }

    // MARK: Playback

    func play(_ sound: TPSound, volume: Float = 1.0) {
        guard !isMuted else { return }
        prepare()
        guard let voices = players[sound.rawValue], !voices.isEmpty else { return }

        let index = (nextVoice[sound.rawValue] ?? 0) % voices.count
        nextVoice[sound.rawValue] = index + 1

        let player = voices[index]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// ループ音を鳴らし始める。すでに鳴っていれば何もしない。
    func startLoop(_ sound: TPSound, volume: Float = 1.0) {
        guard !isMuted else { return }
        prepare()
        guard let player = players[sound.rawValue]?.first else { return }
        guard !player.isPlaying else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func stop(_ sound: TPSound) {
        players[sound.rawValue]?.forEach { $0.stop() }
    }

    func stopLoops() {
        stop(.scan)
        stop(.analyzing)
    }

    func stopAll() {
        players.values.flatMap { $0 }.forEach { $0.stop() }
    }

    /// 設定を変えたら次の再生から新しいセットを使う。
    func invalidate() {
        stopAll()
        loaded = nil
    }
}
