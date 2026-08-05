# TruthPulse — 実装状況

Swift 6 / SwiftUI / iOS 18.0+ / SwiftData / Observation Framework

## はじめかた

**`TruthPulse.xcodeproj` をダブルクリックして ⌘R。** これだけです。

実機で動かす手順（署名設定・デベロッパモード・トラブルシューティング）は
**[RUN.md](RUN.md)** にまとめてあります。

プロジェクトは Xcode 16 の**同期グループ**方式で構成しているため、
`TruthPulse/` 配下にファイルを足し引きしてもプロジェクト設定を触る必要はありません。
カメラ用途説明（`NSCameraUsageDescription`）もビルド設定に埋め込み済みです。

依存ライブラリはありません。

### シミュレータでの動作

シミュレータにはカメラがないため、`FaceTrackingService` が自動で
**シミュレーションモード**に切り替わり、2つのダミー顔が5秒かけて
中央に寄っていきます。UI とステートマシンの確認はシミュレータで完結し、
実機は最終確認のときだけで足ります。カメラ権限を拒否した場合も同じ
モードにフォールバックするので、画面が死ぬことはありません。

## ファイル構成

```
lie_checker/
├── TruthPulse.xcodeproj     Xcode プロジェクト（同期グループ方式）
├── RUN.md                   実機で動かす手順
├── mockups/                 デザイン確認用の HTML モックアップ
└── TruthPulse/                       ソース（この配下は Xcode が自動認識）
    ├── App/
    │   └── TruthPulseApp.swift          @main / ModelContainer 注入
    ├── DesignSystem/
    │   ├── TPTheme.swift                カラー・タイポ・メトリクスのトークン
    │   └── GlassCard.swift              ガラス背景 / Pill / CTA ボタン
    ├── Models/
    │   └── ScanSession.swift            SwiftData モデル・Verdict・AnalysisFactor
    ├── Features/ModeSelect/
    │   ├── ModeSelectView.swift         エントリー画面（モック 01）・TPRoute 定義
    │   └── Components/
    │       ├── PulseLogo.swift          3 重リングのブランドマーク
    │       └── ModeCard.swift           モード選択カード
    ├── Features/SoloSession/
    │   ├── SoloSessionView.swift        メイン計測画面（モック 02）
    │   ├── SoloSessionViewModel.swift   @Observable ステートマシン
    │   ├── BioSignalEngine.swift        擬似生体信号の合成 + 判定合成
    │   └── Components/
    │       ├── ScoreRingView.swift      脈動するスコアリング
    │       ├── WaveformView.swift       Canvas 波形
    │       ├── BioMetricsRow.swift      Pulse / Micro-T / Stress
    │       └── TouchSensorPad.swift     擬似タッチセンサー
    ├── Features/DuoSession/
    │   ├── DuoSessionView.swift         顔認識スキャン画面（モック 03）
    │   ├── DuoSessionViewModel.swift    SYNC 値とロック判定のステートマシン
    │   ├── FaceTrackingService.swift    Vision 顔検出 + シミュレーション
    │   ├── CameraPreviewView.swift      AVCaptureVideoPreviewLayer ラッパー
    │   └── Components/
    │       └── FaceFrameOverlay.swift   ブラケット・メッシュ・リンクライン
    ├── Features/Result/
    │   ├── ResultView.swift             判定結果の詳細画面（モック 04）
    │   ├── ShareCardView.swift          SNS 共有用カード + ImageRenderer
    │   └── Components/
    │       ├── VerdictBadge.swift       衝撃波つき判定バッジ
    │       └── FactorBarRow.swift       内訳バー 1 本
    └── Features/History/
        └── SessionHistoryView.swift     履歴リスト（モック 05 の暫定版）
```

## 実装済み

- [x] デザインシステム（Spatial Bio-Tech トークン）
- [x] SwiftData 永続化（ScanSession / BioSample）
- [x] モード選択画面（モック 01）＋ NavigationStack による導線
- [x] ソロ・セッション画面（質問入力 → 計測 → 解析 → 結果）
- [x] デュオ・顔認識スキャン（モック 03・Vision + AVFoundation）
- [x] 結果詳細画面（判定バッジ・内訳バー 4 本・メタ情報・共有）
- [x] シェアカード生成（ImageRenderer @3x / 1080×1350px）
- [x] セッション履歴リスト（暫定版）
- [x] 心拍同期の触覚フィードバック、判定時の success / warning
- [x] Reduce Motion / Reduce Transparency / Dynamic Type AX / VoiceOver 対応

**ソロ・デュオの両モードが一周します**（起動 → モード選択 → 計測 → 判定 → 共有 → 履歴）。

## 未実装（次の候補）

- [ ] ダッシュボード（モック 05・時間帯別グラフつき。履歴リストを置き換え）
- [ ] Dynamic Island（ActivityKit）と Widget（WidgetKit）

## 画面遷移

```
RootView (NavigationStack, path: [TPRoute])
└── ModeSelectView
    ├── .soloSession → SoloSessionView
    │                  └── fullScreenCover → ResultView
    ├── .duoSession  → DuoSessionView
    │                  └── fullScreenCover → ResultView
    └── .history     → SessionHistoryView
                       └── fullScreenCover → ResultView（onRetry なし）
```

## デュオモードのチューニング値

`DuoSessionViewModel` の先頭にまとめてあります。実機で触りながら調整してください。

| 定数 | 値 | 意味 |
|---|---|---|
| `minGap` | 0.18 | 顔の中心間距離（正規化）。これ以下で SYNC 100% |
| `maxGap` | 0.46 | これ以上で SYNC 0% |
| `lockThreshold` | 0.72 | スキャン開始に必要な SYNC |
| `releaseThreshold` | 0.52 | 継続に必要な SYNC（ヒステリシス） |
| `lockHoldDuration` | 1.0s | ロック確定までの保持時間 |

## 設計メモ

**判定ロジックは意図的に「それらしい」だけ。**
`BioSignalEngine.synthesize` が、指の移動量から算出した動揺量（60%）、質問文の
FNV-1a ハッシュ（30%）、指を離した回数（10%）を混ぜてスコアを合成し、最後に
±6 のゆらぎを足しています。同じ質問なら似た傾向が出るので「再現性のある機械」
に見えつつ、完全には読めません。

**プレビュー**
各ファイルに `#Preview` を用意しています。`SoloSessionView.swift` には
Dynamic Type AX3 + Reduce Motion のプレビューも含まれます。
