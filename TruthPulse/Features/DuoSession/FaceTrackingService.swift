//
//  FaceTrackingService.swift
//  TruthPulse
//
//  Vision の顔矩形検出だけを使った軽量トラッカー。
//  ランドマークや表情解析は行いません（このアプリは判定を演出するだけなので不要）。
//
//  シミュレータではカメラが使えないため、2 つのダミー矩形が寄っていく
//  シミュレーションモードに自動で切り替わります。
//

import AVFoundation
import Observation
import SwiftUI
import Vision

// MARK: - Model

struct DetectedFace: Identifiable, Equatable, Sendable {
    /// 画面左から 0, 1
    let id: Int
    /// SwiftUI の正規化座標（原点は左上、0...1）
    let bounds: CGRect

    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
}

// MARK: - Service

@MainActor
@Observable
final class FaceTrackingService {

    enum Source: Equatable {
        case live        // 実機カメラ
        case simulated   // シミュレータ / カメラ拒否時

        static var `default`: Source {
            #if targetEnvironment(simulator)
            .simulated
            #else
            .live
            #endif
        }
    }

    enum Authorization: Equatable {
        case notDetermined, authorized, denied
    }

    private(set) var faces: [DetectedFace] = []
    private(set) var authorization: Authorization = .notDetermined
    private(set) var isRunning = false
    private(set) var source: Source
    /// カメラバッファの実寸（回転後）。プレビューの aspect-fill 変換に使う。
    /// シミュレーション時は .zero（＝変換不要）。
    private(set) var bufferSize: CGSize = .zero

    /// プレビューレイヤーに渡すセッション。simulated のときは nil。
    var captureSession: AVCaptureSession? {
        source == .live ? controller.session : nil
    }

    private let controller = CameraController()
    private var simulationTask: Task<Void, Never>?

    init(source: Source = .default) {
        self.source = source
    }

    // MARK: Lifecycle

    func start() async {
        guard !isRunning else { return }

        switch source {
        case .simulated:
            authorization = .authorized
            startSimulation()

        case .live:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
            guard granted else {
                // 権限がなくても画面が死なないよう、シミュレーションに退避する
                source = .simulated
                startSimulation()
                isRunning = true
                return
            }
            controller.start { [weak self] detected, size in
                Task { @MainActor in
                    self?.faces = detected
                    self?.bufferSize = size
                }
            }
        }

        isRunning = true
    }

    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        controller.stop()
        faces = []
        bufferSize = .zero
        isRunning = false
    }

    // MARK: Simulation

    /// 2 つの矩形が 5 秒かけて中央へ寄り、そこで小さく揺れ続ける。
    private func startSimulation() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            var t: TimeInterval = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                t += 0.05

                // 0.40（離れている）→ 0.16（密着）へイージング
                let approach = min(t / 5.0, 1)
                let eased = 1 - pow(1 - approach, 3)
                let halfGap = 0.40 - (0.40 - 0.16) * eased

                let wobble = sin(t * 1.7) * 0.012
                let bob = cos(t * 2.3) * 0.010

                let width = 0.30
                let height = 0.22

                let left = CGRect(
                    x: 0.5 - halfGap - width / 2 + wobble,
                    y: 0.40 + bob,
                    width: width, height: height
                )
                let right = CGRect(
                    x: 0.5 + halfGap - width / 2 - wobble,
                    y: 0.40 - bob,
                    width: width, height: height
                )

                self?.faces = [
                    DetectedFace(id: 0, bounds: left),
                    DetectedFace(id: 1, bounds: right)
                ]
            }
        }
    }
}

// MARK: - Camera pipeline

/// AVFoundation と Vision を自前のシリアルキュー上で完結させる。
/// MainActor から切り離すため `@unchecked Sendable`。
private final class CameraController: NSObject, @unchecked Sendable {

    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "app.truthpulse.camera", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var onFaces: (@Sendable ([DetectedFace], CGSize) -> Void)?
    private var isConfigured = false
    /// 3 フレームに 1 回だけ Vision に流す（30fps → 10fps 相当）
    private var frameCounter = 0

    func start(onFaces: @escaping @Sendable ([DetectedFace], CGSize) -> Void) {
        queue.async { [self] in
            self.onFaces = onFaces
            if !isConfigured {
                configure()
                isConfigured = true
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            onFaces = nil
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        // NOTE: connection には回転も鏡像も設定しません。
        //
        // AVCaptureVideoDataOutput の videoRotationAngle は、環境によって
        // バッファに反映されないことがあります（実機で 1920x1080 のまま届きました）。
        // 効くかどうかに依存する設計は壊れやすいので、バッファは素のまま受け取り、
        // 向きの解釈は Vision 側（CGImagePropertyOrientation）に一本化します。

        session.commitConfiguration()
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter &+= 1
        guard frameCounter % 3 == 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3

        // バッファは素の向き（インカメは横長・非鏡像）で届く。
        let rawWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let rawHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // .leftMirrored を渡すと、Vision は「ポートレートに立てて左右反転した状態」
        // として解釈する。これはプレビューレイヤーが既定で見せている向きと一致する。
        // その空間では幅と高さが入れ替わる。
        let bufferSize = CGSize(width: rawHeight, height: rawWidth)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])

        let observations = (request.results ?? [])
            .sorted { $0.boundingBox.midX < $1.boundingBox.midX }
            .prefix(2)

        // Vision は左下原点・正規化。SwiftUI の左上原点に変換する。
        let detected = observations.enumerated().map { index, face in
            let box = face.boundingBox
            return DetectedFace(
                id: index,
                bounds: CGRect(
                    x: box.minX,
                    y: 1 - box.maxY,
                    width: box.width,
                    height: box.height
                )
            )
        }

        onFaces?(detected, bufferSize)
    }
}
