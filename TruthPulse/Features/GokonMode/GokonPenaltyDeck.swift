//
//  GokonPenaltyDeck.swift
//  TruthPulse
//
//  罰ゲームルーレット（20 種）。
//
//  飲酒を強いるもの（一気飲み等）は一切含めない。実害があるうえ、
//  App Store の年齢制限が 4+ から 17+ に上がるため（BACKLOG.md）。
//  「隣の人のいいところを3つ言う」のような、場が続く方向のものだけにしている。
//

import Foundation

struct GokonPenalty: Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
}

enum GokonPenaltyDeck {
    static let all: [GokonPenalty] = [
        .init(id: 1, text: "隣の人のいいところを3つ言う"),
        .init(id: 2, text: "この中の誰か一人を1分間褒め続ける"),
        .init(id: 3, text: "次に聞かれた質問には絶対に本音で答える"),
        .init(id: 4, text: "誰か一人に「ありがとう」を伝える"),
        .init(id: 5, text: "自分の好きなところを3つ発表する"),
        .init(id: 6, text: "一番仲良くなりたい人に話しかける"),
        .init(id: 7, text: "みんなに自分の特技を披露する"),
        .init(id: 8, text: "隣の人とハイタッチする"),
        .init(id: 9, text: "この中の誰かに似顔絵を描いてもらう"),
        .init(id: 10, text: "今日の感想を一言でまとめる"),
        .init(id: 11, text: "この中の誰かのモノマネをする"),
        .init(id: 12, text: "変な自己紹介でもう一度自己紹介する"),
        .init(id: 13, text: "次の1分間、ずっと敬語で話す"),
        .init(id: 14, text: "この中の誰かと指切りをする"),
        .init(id: 15, text: "今の気持ちを一言で叫ぶ"),
        .init(id: 16, text: "一番緊張していそうな人を励ます"),
        .init(id: 17, text: "スマホの待ち受け画面をみんなに見せる"),
        .init(id: 18, text: "この中の誰かに質問できる権利を1つあげる"),
        .init(id: 19, text: "30秒間、笑顔をキープし続ける"),
        .init(id: 20, text: "次のお題を自分で考えて出す")
    ]
}
