# TruthPulse — 実機で動かす手順

所要時間: 初回 10 分程度（Apple ID があれば無料で実機に入れられます）

## 必要なもの

| 項目 | 条件 |
|---|---|
| Mac | macOS Sequoia 以降 |
| Xcode | **16.0 以降**（Swift 6 / objectVersion 77 を使用） |
| iPhone | **iOS 18.0 以降**、TrueDepth でなくてよい（インカメがあれば可） |
| Apple ID | 無料のもので可（有料の Developer Program は不要） |
| ケーブル | Lightning / USB-C。初回は有線接続を推奨 |

---

## 手順

### 1. プロジェクトを開く

Finder で `lie_checker` フォルダを開き、**`TruthPulse.xcodeproj`** をダブルクリック。

ソースは「同期グループ」方式で登録してあるので、`TruthPulse/` 配下のファイルは
自動で認識されます。ファイルを追加・削除しても、プロジェクトを触る必要はありません。

### 2. Bundle Identifier を自分のものに変える

`com.example.TruthPulse` のままだと他人と衝突して署名が通らないことがあります。

1. 左のファイル一覧の一番上、青いアイコンの **TruthPulse** をクリック
2. TARGETS → **TruthPulse** → **Signing & Capabilities** タブ
3. **Bundle Identifier** を書き換える
   例: `com.あなたの名前.truthpulse`（英数字とドットのみ）

### 3. 署名チームを設定する

同じ **Signing & Capabilities** タブで:

1. **Automatically manage signing** に ✅ が入っていることを確認
2. **Team** のプルダウン → **Add an Account...**
3. Apple ID でサインイン
4. Team に「(あなたの名前) (Personal Team)」を選択

赤いエラーが消えれば OK です。

### 4. iPhone を接続して信頼する

1. iPhone を Mac に接続
2. iPhone 側に「このコンピュータを信頼しますか？」→ **信頼**
3. iPhone の **設定 → プライバシーとセキュリティ → デベロッパモード** を **オン**
   （項目が見当たらない場合は、一度 Xcode から実行を試みると出現します）
4. iPhone が再起動 → パスコード入力

### 5. 実行

1. Xcode 上部中央のデバイス選択（`TruthPulse > iPhone …`）で **自分の iPhone** を選ぶ
2. **⌘R** を押す

初回は「開発元を検証できません」と出て起動できません。その場合:

**iPhone の 設定 → 一般 → VPN とデバイス管理 → デベロッパApp** から
自分の Apple ID を選び、**「(あなたの Apple ID) を信頼」** をタップ。

その後もう一度 ⌘R。

---

## 動作確認の順序

1. **起動 → モード選択画面**
   ロゴのリングが 1.1 秒周期で広がっていれば正常です。

2. **ソロ・スキャン**
   質問を入力 → 「スキャンを開始」→ 画面下のエリアに**指を置いたまま 8 秒**。
   - 心拍に合わせて指先が軽く振動すれば、触覚が効いています
   - 指を動かすほどスコアが下がります（動揺量として拾っています）
   - 途中で指を離すと計測が止まり、3 秒以内に戻せば続きから再開します

3. **結果画面 → シェア**
   共有アイコンから画像が生成されます。写真に保存して 1080×1350px か確認してください。

4. **デュオ・スキャン**（ここが実機でしか試せません）
   質問入力 → 「カメラを起動」→ カメラ許可を **許可**。
   - 2 人でインカメに収まると、両方の顔に枠が付きます
   - 顔を近づけると SYNC% が上がり、**72% を 1 秒保持**でスキャン開始
   - スキャン中に離れると「SIGNAL LOST」、近づけ直すと再開

5. **履歴**
   モード選択に戻ると「今夜のスコア N件」に変わっているはずです。

---

## チューニングしたくなったら

顔認識の閾値は `TruthPulse/Features/DuoSession/DuoSessionViewModel.swift` の
`// MARK: - Tuning` にまとめてあります。

```swift
private static let minGap: Double = 0.18          // これ以下で SYNC 100%
private static let maxGap: Double = 0.46          // これ以上で SYNC 0%
private static let lockThreshold: Double = 0.72   // 開始に必要な SYNC
private static let releaseThreshold: Double = 0.52 // 継続に必要な SYNC
private static let lockHoldDuration: TimeInterval = 1.0
```

**近づいてもスキャンが始まらない** → `lockThreshold` を 0.60 くらいに下げる
**すぐ始まってしまう** → `lockThreshold` を 0.80 に上げる、または `minGap` を 0.14 に
**中断が多すぎる** → `releaseThreshold` を 0.40 に下げる

計測時間は `TruthPulse/DesignSystem/TPTheme.swift` の
`samplingDuration`（ソロ 8 秒）/ `duoSamplingDuration`（デュオ 6 秒）です。

---

## トラブルシューティング

**「Signing for TruthPulse requires a development team」**
→ 手順 3 が未完了です。Team を選んでください。

**「Unable to install ... The maximum number of apps for free development profiles has been reached」**
→ 無料アカウントは同時に 3 つまでです。iPhone から他の開発中アプリを削除してください。

**アプリが起動直後に落ちる（デュオ画面で）**
→ カメラ用途説明が読めていません。プロジェクト設定 → Build Settings で
`INFOPLIST_KEY_NSCameraUsageDescription` に値が入っているか確認してください
（既定で設定済みです）。

**カメラが真っ暗**
→ 設定 → TruthPulse → カメラ が オフになっています。オンにしてください。
なお拒否したままでもアプリは落ちず、ダミー顔のシミュレーションで動きます。

**顔枠が左右反転して見える**
→ インカメは鏡像表示にしてあります（`isVideoMirrored = true`）。
自然に見えない場合は `FaceTrackingService.swift` の同行を `false` にしてください。

**プロファイルの有効期限が切れた（7 日後）**
→ 無料アカウントの署名は 7 日で切れます。Xcode から ⌘R で入れ直せば再び 7 日使えます。

---

## 現在の実装範囲

実装済み: モード選択 / ソロ・スキャン / デュオ・顔認識 / 結果詳細 / シェア / 履歴

未実装: ダッシュボード（グラフ付き）/ Dynamic Island / ウィジェット

詳細は `README.md` を参照してください。
