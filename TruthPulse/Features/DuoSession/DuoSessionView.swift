//
//  DuoSessionView.swift
//  TruthPulse
//
//  デュオ・顔認識スキャン（モックアップ 03）。
//
//  NOTE: 型チェック時間を抑えるため、body は極力小さく保ち、
//        座標計算はすべて明示的な型注釈つきのメソッドに逃がしています。
//

import AVFoundation
import SwiftUI
import SwiftData

@MainActor
struct DuoSessionView: View {

    @State private var viewModel = DuoSessionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var questionFocused: Bool

    /// 保存済みセッション。セットされると結果画面がせり上がり、
    /// 閉じられると nil に戻る（＝そのまま次の計測を始める合図）。
    @State private var completedSession: ScanSession?

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) { closeButton }
            .onChange(of: viewModel.phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }
            .onChange(of: completedSession) { _, session in
                handleResultDismissed(session)
            }
            .fullScreenCover(item: $completedSession) { session in
                ResultView(session: session, onRetry: {})
            }
            .onDisappear { viewModel.stopCamera() }
    }

    private var content: some View {
        ZStack {
            cameraLayer

            if viewModel.phase == .setup {
                setupSheet
            } else {
                faceOverlays
                topStatus
                bottomGuide
            }
        }
        // NOTE: アニメーションは content にだけ掛ける。
        // body 直下に置くと fullScreenCover の表示状態まで暗黙アニメーションの
        // 対象になり、提示が取りこぼされることがあります。
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: viewModel.phase)
    }

    private func handlePhaseChange(_ newPhase: DuoSessionViewModel.Phase) {
        guard newPhase == .result else { return }
        completedSession = viewModel.persist(in: modelContext)
    }

    /// 結果画面が閉じられたら、そのまま次の計測に戻る。
    /// 「もう一問」も「閉じる」も同じ挙動でよい（パーティーで連続して回すため）。
    private func handleResultDismissed(_ session: ScanSession?) {
        guard session == nil, viewModel.phase == .result else { return }
        Task { await viewModel.rescan() }
    }

    // MARK: - Camera

    @ViewBuilder
    private var cameraLayer: some View {
        if let session = viewModel.tracker.captureSession {
            CameraPreviewView(session: session)
                .ignoresSafeArea()
                .overlay { cameraTint }
        } else {
            SimulatedCameraBackdrop()
        }
    }

    /// 映像の上に置くティント。UI の可読性を確保する。
    private var cameraTint: some View {
        LinearGradient(
            colors: [
                TPColor.void.opacity(0.55),
                TPColor.void.opacity(0.15),
                TPColor.void.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Face overlays

    /// カメラ映像は `.resizeAspectFill` で表示しているため、画面より大きく描画され
    /// 端が切り取られている。Vision の正規化座標をそのまま画面幅に掛けるとズレるので、
    /// 「実際に描画されているサイズ」と「はみ出したぶんのオフセット」を先に求める。
    private struct PreviewTransform {
        let displaySize: CGSize
        let offset: CGPoint

        init(view: CGSize, buffer: CGSize) {
            guard buffer.width > 0, buffer.height > 0 else {
                // シミュレーションモードは画面いっぱいに描くので変換不要
                self.displaySize = view
                self.offset = .zero
                return
            }
            let scaleX: CGFloat = view.width / buffer.width
            let scaleY: CGFloat = view.height / buffer.height
            let scale: CGFloat = max(scaleX, scaleY)   // aspect fill
            let width: CGFloat = buffer.width * scale
            let height: CGFloat = buffer.height * scale
            self.displaySize = CGSize(width: width, height: height)
            self.offset = CGPoint(x: (view.width - width) / 2,
                                  y: (view.height - height) / 2)
        }

        func rect(from normalized: CGRect) -> CGRect {
            let x: CGFloat = normalized.minX * displaySize.width + offset.x
            let y: CGFloat = normalized.minY * displaySize.height + offset.y
            let w: CGFloat = normalized.width * displaySize.width
            let h: CGFloat = normalized.height * displaySize.height
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }

    private func screenRects(in size: CGSize) -> [CGRect] {
        let transform = PreviewTransform(view: size, buffer: viewModel.tracker.bufferSize)
        return viewModel.faces.map { transform.rect(from: $0.bounds) }
    }

    private func midpoint(_ a: CGRect, _ b: CGRect) -> CGPoint {
        let x: CGFloat = (a.midX + b.midX) / 2
        let y: CGFloat = (a.midY + b.midY) / 2
        return CGPoint(x: x, y: y)
    }

    private var faceOverlays: some View {
        GeometryReader { proxy in
            overlayStack(rects: screenRects(in: proxy.size))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func overlayStack(rects: [CGRect]) -> some View {
        ZStack {
            if rects.count >= 2 {
                linkLayer(first: rects[0], second: rects[1])
            }

            ForEach(rects.indices, id: \.self) { index in
                FaceFrameOverlay(
                    rect: rects[index],
                    tint: frameTint(for: index),
                    isLocked: isLocked
                )
            }
        }
    }

    @ViewBuilder
    private func linkLayer(first: CGRect, second: CGRect) -> some View {
        let center: CGPoint = midpoint(first, second)
        let badgeY: CGFloat = center.y - 26

        FaceLinkLine(
            from: CGPoint(x: first.midX, y: first.midY),
            to: CGPoint(x: second.midX, y: second.midY),
            sync: viewModel.sync
        )

        syncBadge
            .position(x: center.x, y: badgeY)
    }

    private var isLocked: Bool {
        viewModel.phase == .locking || viewModel.phase == .sampling
    }

    private func frameTint(for index: Int) -> Color {
        if isLocked { return TPColor.truth }
        return index == 0 ? TPColor.deceit : TPColor.cyan
    }

    private var syncBadge: some View {
        // Text の文字列補間は LocalizedStringKey のオーバーロード解決が重いため、
        // 先に String を組み立ててから渡す。
        let percent: Int = Int(viewModel.sync * 100)
        let distance: Int = viewModel.distanceCM
        let label: String = "同期率 " + String(percent) + "% ・ 距離 " + String(distance) + "cm"
        let tint: Color = isLocked ? TPColor.truthText : TPColor.cyan

        return Text(label)
            .font(TPFont.mono(10))
            .tracking(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background { syncBadgeBackground }
    }

    private var syncBadgeBackground: some View {
        let stroke: Color = (isLocked ? TPColor.truth : TPColor.cyan).opacity(0.4)

        return ZStack {
            Capsule().fill(TPColor.void.opacity(0.85))
            Capsule().strokeBorder(stroke, lineWidth: 1)
        }
    }

    // MARK: - Status

    private var topStatus: some View {
        VStack {
            statusPill
                .padding(.top, 8)
            Spacer()
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch viewModel.phase {
        case .searching:
            TPPill(kind: .neutral, text: searchingText, showsPulsingDot: true)
        case .aligning:
            TPPill(kind: .neutral, text: "位置合わせ")
        case .locking:
            TPPill(kind: .ok, text: lockingText)
        case .sampling:
            TPPill(kind: .live, text: "スキャン中", showsPulsingDot: true)
        case .lost:
            TPPill(kind: .live, text: "信号ロスト")
        case .analyzing:
            TPPill(kind: .neutral, text: "解析中", showsPulsingDot: true)
        default:
            EmptyView()
        }
    }

    private var searchingText: String {
        let found: Int = viewModel.faces.count
        return "顔を検出中 " + String(found) + "/2"
    }

    private var lockingText: String {
        let percent: Int = Int(viewModel.lockProgress * 100)
        return "固定中 " + String(percent) + "%"
    }

    // MARK: - Bottom guide

    private var bottomGuide: some View {
        VStack(spacing: 0) {
            Spacer()
            guidanceText
            progressBar
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 34)
        }
    }

    private var guidanceText: some View {
        let guidance = viewModel.guidance

        return VStack(spacing: 5) {
            Text(guidance.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TPColor.textPrimary)
            Text(guidance.detail)
                .font(TPFont.body(12))
                .foregroundStyle(TPColor.textSecondary)
                .tpLineSpacing(12)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, TPMetrics.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            progressFill(width: proxy.size.width)
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("スキャン進捗")
        .accessibilityValue(progressA11yValue)
    }

    private var progressA11yValue: String {
        let percent: Int = Int(barFraction * 100)
        return String(percent) + " パーセント"
    }

    private func progressFill(width: CGFloat) -> some View {
        let fraction: CGFloat = CGFloat(barFraction)
        let filled: CGFloat = max(0, width * fraction)

        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [TPColor.deceit, TPColor.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: filled)
        }
    }

    /// ロック中はロック進捗、スキャン中はスキャン進捗を同じバーで見せる。
    private var barFraction: Double {
        switch viewModel.phase {
        case .locking:
            return viewModel.lockProgress
        case .sampling, .lost, .analyzing:
            return viewModel.progress
        default:
            return viewModel.sync
        }
    }

    // MARK: - Setup

    private var setupSheet: some View {
        VStack {
            Spacer()
            setupCard
                .padding(.horizontal, TPMetrics.screenPadding)
                .padding(.bottom, 40)
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: TPMetrics.grid * 1.5) {
            setupHeader

            Text("2人で顔を寄せると計測が始まります。\n質問の入力は任意です。")
                .font(TPFont.body(13))
                .foregroundStyle(TPColor.textSecondary)
                .tpLineSpacing(13)

            questionField
            startButton

            if viewModel.tracker.source == .simulated {
                simulatorNotice
            }

        }
        .glassCard(padding: 20)
    }

    private var setupHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 18))
                .foregroundStyle(TPColor.deceitText)
            Text("デュオ・スキャン")
                .font(TPFont.title(18))
                .foregroundStyle(TPColor.textPrimary)
        }
    }

    private var questionField: some View {
        TextField("質問（任意）　例: 私のことどう思ってる？", text: $viewModel.question, axis: .vertical)
            .font(TPFont.body(15))
            .foregroundStyle(TPColor.textPrimary)
            .tint(TPColor.cyan)
            .lineLimit(1...3)
            .focused($questionFocused)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background { GlassBackground(cornerRadius: 16) }
            .accessibilityLabel("質問を入力、任意")
    }

    private var startButton: some View {
        TPButton(title: "カメラを起動", systemImage: "camera.fill") {
            questionFocused = false
            Task { await viewModel.startCamera() }
        }
        .opacity(viewModel.canStart ? 1 : 0.4)
        .disabled(!viewModel.canStart)
    }

    private var simulatorNotice: some View {
        let message: String = viewModel.tracker.authorization == .denied
            ? "カメラへのアクセスが許可されていないため、シミュレーションで動作します。"
            : "シミュレータではカメラが使えないため、2つのダミー顔で動作します。"

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(TPColor.caution)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(TPColor.textTertiary)
                .tpLineSpacing(11)
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(TPColor.caution.opacity(0.10))
        }
    }


    // MARK: - Close

    private var closeButton: some View {
        Button {
            viewModel.stopCamera()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TPColor.textSecondary)
                .frame(width: 34, height: 34)
                .background { GlassBackground(cornerRadius: 12) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("戻る")
        .padding(.leading, TPMetrics.screenPadding)
        .padding(.top, 6)
    }
}

// MARK: - Previews

#Preview("デュオ・スキャン") {
    DuoSessionView()
        .modelContainer(TPModelContainer.preview)
}
