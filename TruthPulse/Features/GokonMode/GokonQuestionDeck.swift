//
//  GokonQuestionDeck.swift
//  TruthPulse
//
//  合コンモードのお題デッキ。4 カテゴリ × 30 問 = 120 問。
//  「次なに聞く？」で場が止まらないよう、進行役が考えなくていい形にしている。
//
//  Resources ではなく Swift の配列で持つ（BACKLOG.md の指定）。
//  フラットな構造体リテラルなので型チェックへの影響も小さい。
//

import Foundation

enum GokonQuestionCategory: String, CaseIterable, Identifiable, Sendable {
    case exploratory
    case romance
    case murky
    case confession

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exploratory: "探り合い"
        case .romance: "恋愛"
        case .murky: "ドロドロ"
        case .confession: "暴露"
        }
    }

    var symbolName: String {
        switch self {
        case .exploratory: "questionmark.circle.fill"
        case .romance: "heart.fill"
        case .murky: "flame.fill"
        case .confession: "megaphone.fill"
        }
    }
}

struct GokonQuestion: Identifiable, Hashable, Sendable {
    let id: Int
    let category: GokonQuestionCategory
    let text: String
}

enum GokonQuestionDeck {

    static func questions(in category: GokonQuestionCategory) -> [GokonQuestion] {
        all.filter { $0.category == category }
    }

    // id 1–30: 探り合い / 31–60: 恋愛 / 61–90: ドロドロ / 91–120: 暴露
    static let all: [GokonQuestion] = [
        .init(id: 1, category: .exploratory, text: "今日の自己紹介、少し盛った"),
        .init(id: 2, category: .exploratory, text: "この中で一番タイプの服装をしている人がいる"),
        .init(id: 3, category: .exploratory, text: "実は人見知りをしている"),
        .init(id: 4, category: .exploratory, text: "今日ここに来る前、鏡を3回以上見た"),
        .init(id: 5, category: .exploratory, text: "第一印象と今の印象が違う人がいる"),
        .init(id: 6, category: .exploratory, text: "実は時間を気にしながら参加している"),
        .init(id: 7, category: .exploratory, text: "今日の会話、半分は聞き流している"),
        .init(id: 8, category: .exploratory, text: "この中で一番話が合いそうな人がもう決まっている"),
        .init(id: 9, category: .exploratory, text: "実は今日の予定を後から入れた"),
        .init(id: 10, category: .exploratory, text: "今、スマホの通知が気になっている"),
        .init(id: 11, category: .exploratory, text: "この中で誰が一番モテそうか、もう決めている"),
        .init(id: 12, category: .exploratory, text: "自己紹介で出身地や学歴を少し盛った"),
        .init(id: 13, category: .exploratory, text: "実は今日、別の予定を断ってきた"),
        .init(id: 14, category: .exploratory, text: "この中の誰かとはもう会っていた気がする"),
        .init(id: 15, category: .exploratory, text: "今日の服、直前に着替えた"),
        .init(id: 16, category: .exploratory, text: "実は人の名前を覚えるのが苦手"),
        .init(id: 17, category: .exploratory, text: "この場を一番盛り上げているのは自分だと思っている"),
        .init(id: 18, category: .exploratory, text: "今日、誰かに気を遣いすぎて疲れている"),
        .init(id: 19, category: .exploratory, text: "このメンバーの中で一番緊張しているのは自分だと思う"),
        .init(id: 20, category: .exploratory, text: "今日ここに来た理由、本当は他にある"),
        .init(id: 21, category: .exploratory, text: "一番静かな人が、実は一番喋りたいと思っている気がする"),
        .init(id: 22, category: .exploratory, text: "自分の話し方、無意識にキャラを作っている"),
        .init(id: 23, category: .exploratory, text: "今日、誰かの発言に内心ツッコミを入れた"),
        .init(id: 24, category: .exploratory, text: "実はこの場のノリに少し無理をしている"),
        .init(id: 25, category: .exploratory, text: "この中で一番先に本音を話しそうなのは自分だと思う"),
        .init(id: 26, category: .exploratory, text: "今日、自己紹介の順番を気にしていた"),
        .init(id: 27, category: .exploratory, text: "最初の5分で今日の相性をだいたい決めている"),
        .init(id: 28, category: .exploratory, text: "この中の誰かの話し方を真似したくなった"),
        .init(id: 29, category: .exploratory, text: "今日、写真を撮られるのが少し苦手だと思った"),
        .init(id: 30, category: .exploratory, text: "実はこの中で一番聞き役に回っている自覚がある"),

        .init(id: 31, category: .romance, text: "今、気になっている人がこの中にいる"),
        .init(id: 32, category: .romance, text: "元恋人とまだ連絡を取っている"),
        .init(id: 33, category: .romance, text: "一目惚れをしたことがある"),
        .init(id: 34, category: .romance, text: "今日、恋人がいないと嘘をついている"),
        .init(id: 35, category: .romance, text: "タイプの顔がこの中にいる"),
        .init(id: 36, category: .romance, text: "告白される方が告白するより多い"),
        .init(id: 37, category: .romance, text: "今、誰かに片思いをしている"),
        .init(id: 38, category: .romance, text: "恋愛では駆け引きをするタイプだ"),
        .init(id: 39, category: .romance, text: "元恋人の連絡先をまだ消していない"),
        .init(id: 40, category: .romance, text: "今日この場に来たのは出会い目的だ"),
        .init(id: 41, category: .romance, text: "好きな人ができると分かりやすいタイプだ"),
        .init(id: 42, category: .romance, text: "今、複数人を同時に気にしている"),
        .init(id: 43, category: .romance, text: "恋愛では追うより追われたい"),
        .init(id: 44, category: .romance, text: "元恋人のSNSをこっそり見ている"),
        .init(id: 45, category: .romance, text: "この中で一番連絡先を交換したい人がもう決まっている"),
        .init(id: 46, category: .romance, text: "好きな人の前では素を出せていない"),
        .init(id: 47, category: .romance, text: "今、本命だと思っている人がいる"),
        .init(id: 48, category: .romance, text: "恋愛経験人数を少なめに言うタイプだ"),
        .init(id: 49, category: .romance, text: "今日、誰かの話し方に少しときめいた"),
        .init(id: 50, category: .romance, text: "遠距離恋愛はしたくないと思っている"),
        .init(id: 51, category: .romance, text: "好きなタイプを聞かれたら少し盛って答える"),
        .init(id: 52, category: .romance, text: "元恋人に未練が少しある"),
        .init(id: 53, category: .romance, text: "この場で一番モテそうな人が気になっている"),
        .init(id: 54, category: .romance, text: "好きな人には態度でバレやすい"),
        .init(id: 55, category: .romance, text: "今、恋愛よりも気になることがある"),
        .init(id: 56, category: .romance, text: "結婚を意識した相手が過去にいる"),
        .init(id: 57, category: .romance, text: "今日ここに来る前、誰かに服装を相談した"),
        .init(id: 58, category: .romance, text: "好きな人ができると連絡の頻度でバレやすい"),
        .init(id: 59, category: .romance, text: "今、この中の誰かをもう少し知りたいと思っている"),
        .init(id: 60, category: .romance, text: "友達の恋人をいいなと思ったことがある"),

        .init(id: 61, category: .murky, text: "この中の誰かの悪口を言ったことがある"),
        .init(id: 62, category: .murky, text: "誰かを利用したことがある"),
        .init(id: 63, category: .murky, text: "本当は今日のメンバーに少し苦手な人がいる"),
        .init(id: 64, category: .murky, text: "誰かに嫉妬したことがこの中である"),
        .init(id: 65, category: .murky, text: "陰で人の評価を下げたことがある"),
        .init(id: 66, category: .murky, text: "グループLINEで既読スルーしたことがある"),
        .init(id: 67, category: .murky, text: "誰かと比較されて悔しかったことがある"),
        .init(id: 68, category: .murky, text: "本当は今日のメンバー構成に一言ある"),
        .init(id: 69, category: .murky, text: "友人関係で駆け引きをしたことがある"),
        .init(id: 70, category: .murky, text: "誰かの噂話を広めたことがある"),
        .init(id: 71, category: .murky, text: "この中の誰かと一度は距離を置きたいと思ったことがある"),
        .init(id: 72, category: .murky, text: "自分より目立つ人を無意識に避けたことがある"),
        .init(id: 73, category: .murky, text: "誰かの成功を素直に喜べなかったことがある"),
        .init(id: 74, category: .murky, text: "友達を天秤にかけたことがある"),
        .init(id: 75, category: .murky, text: "本当はこの中の誰かと張り合っている"),
        .init(id: 76, category: .murky, text: "誰かに嘘の理由で予定を断ったことがある"),
        .init(id: 77, category: .murky, text: "グループ内で味方を作ろうとしたことがある"),
        .init(id: 78, category: .murky, text: "誰かの発言をわざと聞こえないふりをしたことがある"),
        .init(id: 79, category: .murky, text: "本当はこの中で一番苦手なタイプの人がいる"),
        .init(id: 80, category: .murky, text: "友人関係が壊れかけたことがある"),
        .init(id: 81, category: .murky, text: "誰かにマウントを取られて悔しかったことがある"),
        .init(id: 82, category: .murky, text: "陰で誰かの真似をされて嫌だったことがある"),
        .init(id: 83, category: .murky, text: "本当は今日、気を遣っている人がいる"),
        .init(id: 84, category: .murky, text: "誰かと張り合って無理をしたことがある"),
        .init(id: 85, category: .murky, text: "友達の秘密を別の人に話したことがある"),
        .init(id: 86, category: .murky, text: "誰かに対するモヤモヤをまだ引きずっている"),
        .init(id: 87, category: .murky, text: "この場の空気を読んで本音を隠している"),
        .init(id: 88, category: .murky, text: "人の失敗の方が話のネタとして盛り上がると思っている"),
        .init(id: 89, category: .murky, text: "本当はこのグループに一言物申したいことがある"),
        .init(id: 90, category: .murky, text: "誰かと仲直りするタイミングを逃している"),

        .init(id: 91, category: .confession, text: "学生時代、カンニングをしたことがある"),
        .init(id: 92, category: .confession, text: "SNSを裏アカで使っている"),
        .init(id: 93, category: .confession, text: "誰かに嘘の自己紹介をしたことがある"),
        .init(id: 94, category: .confession, text: "終電を逃したふりをしたことがある"),
        .init(id: 95, category: .confession, text: "実は資格や経歴を少し盛ったことがある"),
        .init(id: 96, category: .confession, text: "遅刻の言い訳を適当に作ったことがある"),
        .init(id: 97, category: .confession, text: "誰かの前で泣いたふりをしたことがある"),
        .init(id: 98, category: .confession, text: "実は今日、体調が万全ではない"),
        .init(id: 99, category: .confession, text: "SNSの投稿は盛って加工している"),
        .init(id: 100, category: .confession, text: "学生時代のあだ名を今でも隠している"),
        .init(id: 101, category: .confession, text: "誰かの誕生日を忘れたことがある"),
        .init(id: 102, category: .confession, text: "実は人の話をあまり覚えていないことがある"),
        .init(id: 103, category: .confession, text: "過去に仮病を使ったことがある"),
        .init(id: 104, category: .confession, text: "プロフィールの年齢や身長を少し盛っている"),
        .init(id: 105, category: .confession, text: "誰かの誕生日会をドタキャンしたことがある"),
        .init(id: 106, category: .confession, text: "実は今日ここに来る交通費を誰かに借りた"),
        .init(id: 107, category: .confession, text: "過去にバイトや仕事を無断で辞めたことがある"),
        .init(id: 108, category: .confession, text: "実は今日の話、少し盛っている"),
        .init(id: 109, category: .confession, text: "誰かに借りたものを返し忘れている"),
        .init(id: 110, category: .confession, text: "SNSのフォロワー数を気にしすぎている"),
        .init(id: 111, category: .confession, text: "実は今日、寝坊しそうだった"),
        .init(id: 112, category: .confession, text: "過去に人の名前を間違えて呼んだことがある"),
        .init(id: 113, category: .confession, text: "資格試験の結果を少し盛って話したことがある"),
        .init(id: 114, category: .confession, text: "誰かに送るはずのメッセージを誤爆したことがある"),
        .init(id: 115, category: .confession, text: "財布を忘れて誰かに奢ってもらったことがある"),
        .init(id: 116, category: .confession, text: "実は今日、忘れ物をしてきた"),
        .init(id: 117, category: .confession, text: "SNSのプロフィール写真は数年前のものだ"),
        .init(id: 118, category: .confession, text: "誰かの誕生日を適当に祝ったことがある"),
        .init(id: 119, category: .confession, text: "実は今、お腹が空いていることを隠している"),
        .init(id: 120, category: .confession, text: "この質問に答えるとき、少し嘘をつく自信がある")
    ]
}
