//
//  CameraPreviewView.swift
//  TruthPulse
//
//  AVCaptureVideoPreviewLayer の薄いラッパー。
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    /// NOTE: プレビューレイヤーの connection には **何も設定しません**。
    ///
    /// AVCaptureVideoPreviewLayer は既定で
    ///   - 画面の向きに合わせて自動で回転する
    ///   - インカメなら自動で鏡像にする
    /// ため、こちらで videoRotationAngle を足すと二重に回って映像が倒れます。
    ///
    /// 解析側（FaceTrackingService）を、この既定の見え方に合わせています。
    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// シミュレータ／権限拒否時に映像の代わりに敷く背景。
struct SimulatedCameraBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0D1024), TPColor.void],
                           startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [TPColor.deceit.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.3, y: 0.38),
                           startRadius: 0, endRadius: 260)
            RadialGradient(colors: [TPColor.cyan.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.7, y: 0.38),
                           startRadius: 0, endRadius: 260)

            ScanlinePattern()
                .stroke(TPColor.cyan.opacity(0.16), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}

/// 4pt ごとの走査線。CRT 風のノイズ感を出す。
private struct ScanlinePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 4
        }
        return path
    }
}

#Preview {
    SimulatedCameraBackdrop()
}
