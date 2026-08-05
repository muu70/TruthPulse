//
//  TPHaptics.swift
//  TruthPulse
//
//  触覚フィードバック。
//
//  SwiftUI の `.sensoryFeedback` はオーバーロードが多く、複数チェーンすると
//  型チェックが破綻する（実測 2.5 秒 / 制限 300ms）ため、UIKit の
//  FeedbackGenerator を直接叩いています。
//  触覚は本来イベント駆動なので、ViewModel から鳴らす方が設計としても素直です。
//

import UIKit

@MainActor
enum TPHaptics {

    // 使い回してレイテンシを下げる
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    /// 計測開始直前に呼ぶと、最初の一拍が遅れない。
    static func prepare() {
        impact.prepare()
        notification.prepare()
    }

    /// 心拍 1 拍ぶん。
    static func heartbeat() {
        impact.impactOccurred(intensity: 0.55)
        impact.prepare()
    }

    /// モード選択・ロック成立など。
    static func select() {
        selection.selectionChanged()
    }

    /// 真実判定。
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// 嘘・保留の判定、指が離れた、ロック喪失。
    static func warning() {
        notification.notificationOccurred(.warning)
    }
}
