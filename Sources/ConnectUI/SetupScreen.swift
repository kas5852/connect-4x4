import ConnectCore
import SwiftUI

struct SetupScreen: View {
    @Bindable var store: GameStore
    @State private var showingRules = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Wordmark()
                    Spacer()
                    Button { showingRules = true } label: {
                        Image(systemName: "questionmark").font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Palette.surface, in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("How to play")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "A LITTLE CHAOS. A LOT OF STRATEGY.")
                    Text("Four boards.\nOne brain.")
                        .font(.system(size: 43, weight: .black, design: .rounded))
                        .tracking(-1.5).lineSpacing(-2).fixedSize(horizontal: false, vertical: true)
                    Text("Connect four. Beat the clock.\nTry keeping up with all of them.")
                        .font(.system(size: 15)).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                DemoBoards()
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Eyebrow(text: "HOW MUCH CHAOS?"); Spacer(); Text("\(store.boardCount) boards").font(.caption).foregroundStyle(Palette.lime) }
                    HStack(spacing: 10) {
                        ForEach(1...4, id: \.self) { count in
                            choiceButton(selected: store.boardCount == count) {
                                store.boardCount = count
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: count == 1 ? "square" : "square.grid.2x2")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(count)").font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }.accessibilityLabel("\(count) \(count == 1 ? "board" : "boards")")
                                .accessibilityIdentifier("board-count-\(count)")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "SECONDS PER TURN")
                    HStack(spacing: 10) {
                        ForEach([8, 12, 20, 30], id: \.self) { seconds in
                            choiceButton(selected: store.turnSeconds == Double(seconds)) {
                                store.turnSeconds = Double(seconds)
                            } label: {
                                Text("\(seconds)s").font(.system(size: 16, weight: .bold, design: .rounded))
                            }.accessibilityLabel("\(seconds) seconds per turn")
                        }
                    }
                    Label("Miss a timer? Autopilot makes a random move.", systemImage: "shuffle")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "YOUR OPPONENT")
                    HStack(spacing: 10) {
                        ForEach(PlayMode.allCases, id: \.self) { mode in
                            choiceButton(selected: store.mode == mode) { store.mode = mode } label: {
                                Label(mode.title, systemImage: mode == .solo ? "bolt.fill" : "person.2.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }.accessibilityIdentifier("mode-\(mode.rawValue)")
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                PrimaryButton(title: "Let’s play", symbol: "arrow.right") { store.start() }
                    .accessibilityIdentifier("start-match")
                Text("CORAL GOES FIRST · NO ACCOUNT. JUST PLAY.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
                .background(Palette.background)
        }
        .sheet(isPresented: $showingRules) { RulesSheet() }
    }

    private func choiceButton<Content: View>(selected: Bool, action: @escaping () -> Void,
                                            @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) {
            label().frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(selected ? Palette.background : Palette.ink)
                .background(selected ? Palette.lime : Palette.surface, in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DemoBoards: View {
    static let sequences = [[3, 2, 3, 4, 2, 4, 3], [2, 3, 2, 4, 4, 3, 5, 5],
                            [3, 4, 2, 4, 3, 5], [4, 3, 5, 4, 2, 2, 3, 3]]
    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("4×\nthe rush.").font(.system(size: 28, weight: .black, design: .rounded)).tracking(-1)
                Label("ALL AT ONCE", systemImage: "bolt.fill")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundStyle(Palette.lime)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    BoardSurface(board: demo(index)).equatable()
                }
            }.frame(maxWidth: 225)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle").foregroundStyle(Palette.lime).padding(10)
            }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Four independent games of Connect Four, played at once")
    }
    private func demo(_ index: Int) -> Board {
        var board = Board()
        for column in Self.sequences[index] { board.drop(in: column) }
        return board
    }
}

struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Text("How to rush").font(.largeTitle.bold()); Spacer(); Button("Done") { dismiss() } }
                rule("01", "Four in a row", "Drop pieces into any open column. Connect four horizontally, vertically, or diagonally to win that board.")
                rule("02", "Every board has a clock", "Each board counts down separately for its current player. Moving resets only that board’s clock.")
                rule("03", "Keep moving", "At zero, a random legal move happens automatically. The clocks keep running while you focus a board or leave the app, and missed moves are resolved when you return.")
                rule("04", "Win the most boards", "Coral goes first. In solo rush, you play Coral against the Gold computer. In pass & play, share the device and take each board’s indicated turn. Most boards won takes the match; equal scores tie.")
                rule("05", "Find your focus", "Tap a board’s expand button for larger controls. The other clocks keep running. Landscape gives four boards more room.")
            }.padding(24).frame(maxWidth: 600)
        }.foregroundStyle(Palette.ink).background(Palette.background)
            .preferredColorScheme(.dark)
    }
    private func rule(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.system(.title2, design: .monospaced).bold()).foregroundStyle(Palette.lime)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(text).font(.body).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
