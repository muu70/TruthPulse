//
//  TouchSensorPad.swift
//  TruthPulse
//
//  擬似タッチセンサー。指を置いている間だけ計測が進みます。
//  ヒットエリアは 150pt 高 × 画面幅（44pt 最小要件を大きく上回る）。
//

import SwiftUI

struct TouchSensorPad: View {

    enum SensorState: Equatable {
        case awaiting        // 指を置いてください
        case reading         // 読み取り中
        case interrupted     // 指が離れた
        case analyzing       // 解析中

        var message: String {
            switch self {
            case .awaiting: "ここに指を置いてください"
            case .reading: "指を離さないでください"
            case .interrupted: "指が離れました。戻してください"
            case .analyzing: "解析中…"
            }
        }

        var tint: Color {
            switch self {
            case .interrupted: TPColor.caution
            case .analyzing: TPColor.purple
            default: TPColor.cyan
            }
        }
    }

    let state: SensorState
    let counterText: String
    let onFingerDown: () -> Void
    let onFingerMoved: (CGSize) -> Void
    let onFingerUp: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var scanOffset: CGFloat = -1
    @State private var haloScale: CGFloat = 0.9

    private let height: CGFloat = 150

    var body: some View {
        ZStack {
            // ベース
            RoundedRectangle(cornerRadius: TPMetrics.padRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [state.tint.opacity(0.20), TPColor.purple.opacity(0.10), .clear],
                        center: .center, startRadius: 4, endRadius: 190
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: TPMetrics.padRadius, style: .continuous)
                        .strokeBorder(
                            state.tint.opacity(isPressed ? 0.85 : 0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: isPressed ? [] : [7, 6])
                        )
                }

            // 走査ライン
            if !reduceMotion && state == .reading {
                GeometryReader { proxy in
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.clear, state.tint, .clear],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 2)
                        .padding(.horizontal, proxy.size.width * 0.08)
                        .offset(y: (proxy.size.height * 0.36) * scanOffset + proxy.size.height / 2)
                }
                .allowsHitTesting(false)
            }

            VStack(spacing: 9) {
                fingerprint
                Text(state.message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(state.tint)
                    .tpLineSpacing(12)

                if state == .reading || state == .interrupted {
                    Text("計測中 " + counterText)
                        .font(TPFont.mono(10))
                        .tracking(1.6)
                        .foregroundStyle(TPColor.textTertiary)
                }
            }
        }
        .frame(height: height)
        .contentShape(RoundedRectangle(cornerRadius: TPMetrics.padRadius, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        onFingerDown()
                    }
                    onFingerMoved(value.translation)
                }
                .onEnded { _ in
                    isPressed = false
                    onFingerUp()
                }
        )
        .onAppear(perform: startScanAnimation)
        .onChange(of: state) { _, _ in startScanAnimation() }
        // MARK: Accessibility
        // VoiceOver 使用時はドラッグが取れないため、ダブルタップで開始/停止できるようにする。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("生体センサー")
        .accessibilityValue(state.message)
        .accessibilityHint("ダブルタップで計測を開始または再開します")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            isPressed ? onFingerUp() : onFingerDown()
            isPressed.toggle()
        }
    }

    private var fingerprint: some View {
        ZStack {
            // 拡散リング
            if !reduceMotion && state == .reading {
                Circle()
                    .strokeBorder(state.tint.opacity(0.45), lineWidth: 1)
                    .frame(width: 88, height: 88)
                    .scaleEffect(haloScale)
                    .opacity(haloScale > 1.1 ? 0 : 0.9)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x9BF3FF).opacity(0.5), state.tint.opacity(0.25)],
                        center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2, endRadius: 42
                    )
                )
                .overlay { Circle().strokeBorder(state.tint.opacity(0.7), lineWidth: 1) }
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(isPressed ? 0.15 : 0.55))
                }
                .shadow(color: state.tint.opacity(0.45), radius: 22)
                .scaleEffect(isPressed ? 0.94 : 1)
                .animation(.spring(duration: 0.25), value: isPressed)
        }
    }

    private func startScanAnimation() {
        guard !reduceMotion, state == .reading else { return }
        scanOffset = -1
        haloScale = 0.9
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            scanOffset = 1
        }
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            haloScale = 1.35
        }
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        VStack(spacing: 16) {
            TouchSensorPad(state: .awaiting, counterText: "00.0秒 / 08.0秒",
                           onFingerDown: {}, onFingerMoved: { _ in }, onFingerUp: {})
            TouchSensorPad(state: .reading, counterText: "04.2秒 / 08.0秒",
                           onFingerDown: {}, onFingerMoved: { _ in }, onFingerUp: {})
        }
        .padding(TPMetrics.screenPadding)
    }
    .preferredColorScheme(.dark)
}
