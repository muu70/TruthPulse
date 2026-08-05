//
//  SoundSettingsBar.swift
//  TruthPulse
//
//  音のミュート切替と、音セットの選択。
//  設定画面を作るほどの分量ではないので、モード選択画面の上部に常設します。
//

import SwiftUI

struct SoundSettingsBar: View {

    @AppStorage(TPAudioSettings.mutedKey) private var isMuted = false
    @AppStorage(TPAudioSettings.setKey) private var rawSet = TPSoundSet.variety.rawValue

    private var currentSet: TPSoundSet {
        TPSoundSet(rawValue: rawSet) ?? .variety
    }

    var body: some View {
        HStack(spacing: 8) {
            muteButton
            Spacer(minLength: 4)
            if !isMuted {
                setPicker
            }
        }
        .frame(height: 34)
        .animation(.snappy(duration: 0.2), value: isMuted)
    }

    // MARK: - Mute

    private var muteButton: some View {
        Button {
            isMuted.toggle()
            if isMuted {
                TPAudio.shared.stopAll()
            } else {
                TPAudio.shared.play(.select, volume: 0.6)
            }
        } label: {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isMuted ? TPColor.textTertiary : TPColor.cyan)
                .frame(width: 34, height: 34)
                .background { GlassBackground(cornerRadius: 12) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "音を鳴らす" : "音を消す")
    }

    // MARK: - Set picker

    private var setPicker: some View {
        HStack(spacing: 4) {
            ForEach(TPSoundSet.allCases) { set in
                setChip(set)
            }
        }
        .padding(3)
        .background { GlassBackground(cornerRadius: 14) }
    }

    private func setChip(_ set: TPSoundSet) -> some View {
        let selected: Bool = set == currentSet
        let fg: Color = selected ? Color(hex: 0x00121F) : TPColor.textSecondary

        return Button {
            rawSet = set.rawValue
            TPAudio.shared.invalidate()
            TPAudio.shared.play(.select, volume: 0.6)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: set.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                Text(set.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background { chipBackground(selected: selected) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(set.displayName + "の音")
        .accessibilityValue(set.summary)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func chipBackground(selected: Bool) -> some View {
        if selected {
            Capsule().fill(TPColor.brandGradient)
        } else {
            Capsule().fill(Color.clear)
        }
    }
}

#Preview {
    ZStack {
        TPColor.backdrop
        VStack {
            SoundSettingsBar()
                .padding(.horizontal, TPMetrics.screenPadding)
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
