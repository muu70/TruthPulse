//
//  MultiTouchPad.swift
//  TruthPulse
//
//  2 本以上の指の座標を同時に取る。
//
//  SwiftUI の DragGesture は同時に 1 本しか扱えないため、UIKit の
//  touchesBegan/Moved/Ended を直接拾っています。
//  ペア判定は「2 人の指がどれだけ近いか」を測るので、複数点が必須です。
//

import SwiftUI
import UIKit

struct MultiTouchPad: UIViewRepresentable {

    /// 画面左からの順に並べた接触点。空配列は「誰も触れていない」。
    let onTouchesChanged: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.onTouchesChanged = onTouchesChanged
        return view
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {
        uiView.onTouchesChanged = onTouchesChanged
    }

    final class TouchTrackingView: UIView {

        var onTouchesChanged: (([CGPoint]) -> Void)?

        /// UITouch は同一オブジェクトが使い回されるので、識別子で追跡する。
        private var points: [ObjectIdentifier: CGPoint] = [:]

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            update(touches)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            update(touches)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            remove(touches)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            remove(touches)
        }

        private func update(_ touches: Set<UITouch>) {
            for touch in touches {
                points[ObjectIdentifier(touch)] = touch.location(in: self)
            }
            report()
        }

        private func remove(_ touches: Set<UITouch>) {
            for touch in touches {
                points.removeValue(forKey: ObjectIdentifier(touch))
            }
            report()
        }

        private func report() {
            // 左から順に並べる。左右が入れ替わっても表示がちらつかないように。
            let sorted = points.values.sorted { $0.x < $1.x }
            onTouchesChanged?(sorted)
        }
    }
}
