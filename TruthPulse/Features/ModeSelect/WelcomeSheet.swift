//
//  WelcomeSheet.swift
//  TruthPulse
//
//  初回起動時に一度だけ出す案内。
//
//  App Review Guideline 1.1.6 は「偽の機能」を禁じており、
//  『エンタメ目的と書けば免除される』とは明記されていません。
//  そのため「これはゲームである」ことを、説明文だけでなくアプリ内でも
//  一度は明示します。
//
//  ただし出すのは初回だけです。毎回出すと、このアプリの核である
//  「本物の機械っぽさ」が壊れてしまうためです。
//

import SwiftUI

struct WelcomeSheet: View {

    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            TPColor.backdrop

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                character
                heading
                points
                Spacer(minLength: 0)
                startButton
            }
            .padding(.horizontal, TPMetrics.screenPadding)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Parts

    private var character: some View {
        UsomiView(score: 24, unit: 66)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(appeared ? 1 : 0)
    }

    private var heading: some View {
        VStack(spacing: 10) {
            Text("これは\nパーティーゲームです")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .multilineTextAlignment(.center)
                .foregroundStyle(TPColor.textPrimary)
                .tpLineSpacing(26)

            Text("本物の嘘発見器ではありません")
                .font(TPFont.body(14))
                .foregroundStyle(TPColor.deceitText)
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity)
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 14) {
            point(icon: "theatermasks.fill",
                  text: "判定はすべて演出です。実際の嘘や感情は測定していません")
            point(icon: "hand.raised.fill",
                  text: "表示される心拍や発汗の数値も、演出のために作られた値です")
            point(icon: "lock.fill",
                  text: "カメラ映像は端末の外に送信されず、保存もされません")
        }
        .padding(.top, 26)
        .padding(.horizontal, 4)
    }

    private func point(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(TPColor.cyan)
                .frame(width: 22)
            Text(text)
                .font(TPFont.body(13.5))
                .foregroundStyle(TPColor.textSecondary)
                .tpLineSpacing(13.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startButton: some View {
        TPButton(title: "わかった、はじめる", systemImage: "play.fill") {
            TPHaptics.select()
            onStart()
        }
        .padding(.top, 28)
    }
}

#Preview {
    WelcomeSheet(onStart: {})
}
