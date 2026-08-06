# TruthPulse — 開発ガイド

嘘発見器「風」のエンタメアプリ。合コンやナンパの場で、10〜30代が
**判定そのものより計測されている時間を楽しむ**ことを狙っています。

Swift 6 / SwiftUI / iOS 18.0+ / SwiftData / Observation Framework。依存ライブラリなし。

---

## いちばん大事な前提

**このアプリは嘘を検出しません。検出しているように見せるだけです。**

判定は `BioSignalEngine.synthesize` が合成しています。

| 要素 | 重み |
|---|---|
| 動揺量（指の移動量 / 顔の移動量） | 60% |
| 質問文の FNV-1a ハッシュ | 30% |
| 中断回数（指を離した / 顔が離れた） | 10% |

最後に ±6 のゆらぎを足します。質問文のハッシュを混ぜているのは、
**同じ質問なら似た結果が出る＝再現性のある機械に見せる**ためです。
質問が空のときは毎回ランダムになります（第三者が口頭で聞く使い方を想定）。

「精度を上げる」方向の変更は、この設計意図に反します。

---

## コマンド

```bash
# 開く（Xcode 16 以降）
open TruthPulse.xcodeproj

# ビルド診断（エラー行番号 + 型チェックが遅い式を洗い出す）
bash diagnose.sh

# 効果音の再生成（周波数やエンベロープを変えたあと）
python3 tools/generate_sounds.py
```

**注意**: シェルからビルドが必要なときは `diagnose.sh` の中の `xcodebuild` を参考に。
`-destination 'generic/platform=iOS Simulator'` を使うと署名なしで通ります。

---

## 踏んだ地雷（同じ穴に落ちないために）

### 1. `.sensoryFeedback` を複数チェーンしない

4 本並べたら **型チェックに 2.5 秒** かかりビルドが通りませんでした（制限 300ms）。
オーバーロードが 3 系統あり、チェーンすると組み合わせが爆発します。

→ 触覚は `TPHaptics`（UIKit の FeedbackGenerator）から直接鳴らします。
ViewModifier に切り出しても中身が同じなら意味がありません。

### 2. `Text("... \(value) ...")` を書かない

`LocalizedStringKey` の補間オーバーロードが大量にあり、補間が 2 つ以上あると重くなります。
特に `format:` 付きが最悪です。

→ 先に `String` を組み立ててから `Text(文字列)` に渡します。
現在コードベースに `Text` の文字列補間は 1 つもありません。

### 3. `body` を大きくしない

40 行を超えたら分割してください。`diagnose.sh` の 3 番目のセクションで
実測できます（`-warn-long-function-bodies=300`）。

### 4. カメラの向きは connection で制御しない

`AVCaptureVideoDataOutput` の `videoRotationAngle = 90` は、**実機でバッファに
反映されませんでした**（1920x1080 のまま届いた）。
また `AVCaptureVideoPreviewLayer` は既定で画面の向きに自動追従・自動鏡像するため、
そこへ回転を足すと二重に回って映像が倒れます。

→ 回転・鏡像の指定は両方の connection から削除済み。
向きの解釈は **Vision の `CGImagePropertyOrientation` (`.leftMirrored`) に一本化**しています。
その空間ではバッファの幅と高さが入れ替わるので、`bufferSize` も入れ替えて渡します。

### 5. SwiftUI のジェスチャでは複数の指を同時に取れない

`DragGesture` は同時に 1 本だけです。ペア判定は 2 点の距離を測るので、
`MultiTouchPad`（UIViewRepresentable + `touchesBegan/Moved/Ended`）を使っています。
`isMultipleTouchEnabled = true` を忘れると 1 本しか来ません。

画面幅の都合で、**同時に置けるのは実用上 4 本まで**です
（指 1 本に 90pt 前後の余裕が要る）。

### 6. プレビューで Reduce Motion は注入できない

`accessibilityReduceMotion` は読み取り専用 KeyPath なので
`.environment(_:_:)` に渡せません（`dynamicTypeSize` と `colorScheme` は可）。
確認はシミュレータの 設定 → アクセシビリティ → 動作 から。

---

## 構成

```
TruthPulse/
├── App/                 @main / ModelContainer 注入 / TPRoute の分岐
├── DesignSystem/
│   ├── TPTheme.swift        カラー・タイポ・メトリクスのトークン
│   ├── GlassCard.swift      ガラス背景 / Pill / CTA ボタン
│   ├── TPHaptics.swift      触覚（UIKit 直叩き）
│   ├── TPAudio.swift        効果音（AVAudioPlayer のボイスプール）
│   ├── SoundSettingsBar.swift  ミュート / 音セット切替
│   └── UsomiView.swift      キャラクター「ウソミ」
├── Models/
│   └── ScanSession.swift    SwiftData / Verdict / VerdictText / AnalysisFactor
├── Resources/               効果音 WAV（生成物。手で編集しない）
└── Features/
    ├── ModeSelect/          エントリー画面
    ├── SoloSession/         指を置いて 8 秒計測 + BioSignalEngine
    ├── DuoSession/          顔認識で 6 秒計測（Vision + AVFoundation）
    ├── PairSession/         2 人が指を近づけて 8 秒計測（マルチタッチ）
    ├── Result/              判定結果 + シェアカード（ImageRenderer）
    └── History/             履歴リスト（ダッシュボードの暫定版）
```

**画面遷移**

```
RootView (NavigationStack, path: [TPRoute])
└── ModeSelectView
    ├── .soloSession → SoloSessionView ─┐
    ├── .duoSession  → DuoSessionView  ─┤
    ├── .pairSession → PairSessionView ─┼→ fullScreenCover → ResultView
    └── .history     → SessionHistoryView ┘（onRetry なしで開く）
```

---

## 規約

- **コメントは日本語**。「何をしているか」ではなく **「なぜそうしたか」** を書く
- UI 文言も日本語。`TruthPulse` と `Bio-Signal Analyzer` だけ英字（ブランド表記）
- 判定は **「本当 / 嘘」の 2 値**。50 点が境界。
  宙ぶらりんな結果（「もう一度計測してください」等）は出さない
  強度は `VerdictText.headline(for:)` の 6 段階の言葉で表現する
- **免責表記は画面に出さない**（ユーザーの明示的な指示。App Store の説明文には入れる想定）
- キャラクターと効果音は **すべてコード生成**。画像・音源アセットを外部から持ち込まない
- アクセシビリティ: Reduce Motion / Reduce Transparency / Dynamic Type AX / VoiceOver
  に対応済み。新しい画面でも同じ水準を保つ

---

## 調整しやすい定数

| 何を | どこ | 現在値 |
|---|---|---|
| ソロの計測時間 | `TPTheme.swift` `samplingDuration` | 8.0 秒 |
| デュオの計測時間 | `TPTheme.swift` `duoSamplingDuration` | 6.0 秒 |
| ペアの計測時間 | `TPTheme.swift` `pairSamplingDuration` | 8.0 秒 |
| 触れ合ったとみなす距離 | `PairSessionViewModel.swift` `contactDistance` | 46pt |
| 同期率 0% になる距離 | 同 `maxDistanceRatio`（パッド幅比） | 0.72 |
| 顔を近づける閾値 | `DuoSessionViewModel.swift` `lockThreshold` | 0.72 |
| 継続に必要な同期率 | 同 `releaseThreshold` | 0.52 |
| 心拍の触覚の強さ | `TPHaptics.swift` `intensity` | 0.55 |
| ウソミの鼻の伸び | `UsomiView.swift` `noseLength` の係数 | 1.35 |

デュオの距離は **顔の幅を基準にした比率**で測っています
（頬がくっつくと約 1.0、肩幅ぶん離れると 2.0 前後）。
正規化座標をそのまま使うとカメラとの距離で基準がぶれるためです。

---

## 未実装

- ダッシュボード（時間帯別グラフつき。`SessionHistoryView` を置き換える想定）
- Dynamic Island（ActivityKit）とウィジェット（WidgetKit）

---

## App Store 提出

手順と掲載文は [RELEASE.md](RELEASE.md)。

**審査で最も注意すべきはガイドライン 1.1.6（偽の機能）です。**
「エンタメ目的と書けば免除される」とは明記されていないため、
初回起動時に `WelcomeSheet` で「これはパーティーゲームです」を全画面表示しています。
**この画面を消さないでください。** 2 回目以降は出さない実装なので、
プレイ体験は損なわれません。

説明文やスクリーンショットで「AI」「解析」「測定」を機能として謳うのも避けます。

アイコンと効果音は生成物です。手で編集せず、スクリプトを直して再実行してください。

```bash
python3 tools/generate_icon.py    # アプリアイコン
python3 tools/generate_sounds.py  # 効果音
```

---

## 動作確認

手順は [TEST.md](TEST.md)。実機の準備は [RUN.md](RUN.md)。

シミュレータでもデュオモードは動きます（カメラがないと 2 つのダミー顔が
5 秒かけて自動で近づくモードに切り替わります）。実機が必要なのは
**触覚**と**本物の顔認識**だけです。
