//
//  TruthPulseApp.swift
//  TruthPulse
//

import SwiftUI
import SwiftData

@main
struct TruthPulseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(TPModelContainer.shared)
    }
}

@MainActor
struct RootView: View {
    @State private var path: [TPRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ModeSelectView(path: $path)
                .navigationDestination(for: TPRoute.self) { route in
                    switch route {
                    case .soloSession:
                        SoloSessionView()
                    case .duoSession:
                        DuoSessionView()
                    case .history:
                        SessionHistoryView()
                    }
                }
        }
        .preferredColorScheme(.dark)
        .tint(TPColor.cyan)
    }
}

#Preview {
    RootView()
        .modelContainer(TPModelContainer.preview)
}
