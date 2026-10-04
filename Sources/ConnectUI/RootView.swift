import SwiftUI

public struct RootView: View {
    @State private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    @MainActor public init(store: GameStore? = nil) {
        _store = State(initialValue: store ?? GameStore())
    }

    public var body: some View {
        Group {
            if let session = store.session { GameScreen(store: store, session: session).id(session.startedAt) }
            else { SetupScreen(store: store) }
        }.foregroundStyle(Palette.ink).background(Palette.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .onAppear { store.setActive(true) }
            .onChange(of: scenePhase) { _, phase in store.setActive(phase == .active) }
    }
}

/// Static snapshots render real UI without changing persistence or starting clocks.
public struct AppSnapshot: View {
    let store: GameStore
    let playing: Bool
    @MainActor public init(store: GameStore, playing: Bool) { self.store = store; self.playing = playing }
    public var body: some View {
        Group {
            if playing, let session = store.session { GameScreen(store: store, session: session) }
            else { SetupScreen(store: store) }
        }.foregroundStyle(Palette.ink).background(Palette.background)
            .preferredColorScheme(.dark)
    }
}

public struct AppIconView: View {
    public init() {}
    public var body: some View {
        ZStack {
            Palette.background
            VStack(spacing: 38) {
                HStack(spacing: 38) { tile(Palette.coral); tile(Palette.gold) }
                HStack(spacing: 38) { tile(Palette.gold); tile(Palette.lime) }
            }.padding(150)
        }.frame(width: 1024, height: 1024)
    }
    private func tile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 68).fill(Palette.board)
            .overlay { Circle().fill(color.gradient).padding(40) }
    }
}
