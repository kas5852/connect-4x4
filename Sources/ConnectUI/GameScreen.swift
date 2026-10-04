import ConnectCore
import SwiftUI

struct GameScreen: View {
    @Bindable var store: GameStore
    let session: Session
    @State private var confirmExit = false
    @State private var showingRules = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { screen in
        VStack(spacing: 0) {
            HStack {
                Wordmark()
                Spacer()
                Button { showingRules = true } label: {
                    Image(systemName: "questionmark.circle").frame(width: 44, height: 44)
                }.accessibilityLabel("How to play")
                Button { confirmExit = true } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                        .frame(width: 44, height: 44).background(Palette.surface, in: Circle())
                }.accessibilityLabel("End match").accessibilityIdentifier("end-match")
            }.padding(.horizontal, 20).padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: session.mode == .solo ? "YOU ARE CORAL" : "TWO PLAYERS · ONE DEVICE")
                            Text(session.finished ? "Nice rush." : "Keep your eyes moving.")
                                .font(.system(size: 23, weight: .black, design: .rounded)).tracking(-0.7)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(session.turnDuration))s").font(.system(size: 26, weight: .black, design: .rounded))
                            Text("PER TURN").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                        }
                    }
                    ScoreStrip(session: session)
                    Group {
                        // Each board remains useful at both phone and tablet widths.
                        let columns = session.rounds.count == 1 ? 1 : 2
                        let gap: CGFloat = 12
                        let cardWidth = (min(810, screen.size.width - 40) - CGFloat(columns - 1) * gap) / CGFloat(columns)
                        TimelineView(.animation(minimumInterval: 0.1, paused: session.finished || store.focusedBoard != nil)) { context in
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columns), spacing: gap) {
                                ForEach(session.rounds) { round in
                                    BoardCard(round: round, duration: session.turnDuration,
                                              now: context.date.timeIntervalSince1970,
                                              solo: session.mode == .solo,
                                              compact: cardWidth < 250,
                                              onFocus: { store.focusedBoard = round.id },
                                              onDrop: { store.drop(column: $0, boardID: round.id) })
                                }
                            }
                        }
                    }.frame(height: gridHeight(width: min(810, screen.size.width - 40)))
                    if session.finished {
                        ResultsPanel(session: session) { store.start() }
                    } else {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "shuffle").foregroundStyle(Palette.lime)
                            Text(store.notice ?? "Tap a column to drop. Out of time? Autopilot takes over.")
                                .foregroundStyle(Palette.muted)
                        }.font(.system(size: 12)).frame(minHeight: 34, alignment: .top)
                        HStack {
                            Label("\(session.timeoutCount) autopilot moves", systemImage: "bolt.horizontal.fill")
                            Spacer()
                            Text("\(session.rounds.filter(\.finished).count)/\(session.rounds.count) finished")
                        }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                }.padding(20).frame(maxWidth: 850).frame(maxWidth: .infinity)
            }
        }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: store.feedback) { _, _ in store.soundlessHaptics && !reduceMotion }
        .confirmationDialog("End this match?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("End match", role: .destructive) { store.leave() }
            Button("Keep playing", role: .cancel) {}
        } message: { Text("Your clocks keep running until you end the match.") }
        .sheet(isPresented: $showingRules) { RulesSheet() }
        .sheet(isPresented: Binding(get: { store.focusedBoard != nil }, set: { if !$0 { store.focusedBoard = nil } })) {
            FocusedBoard(store: store)
        }
    }

    private func gridHeight(width availableWidth: CGFloat) -> CGFloat {
        let columns = session.rounds.count == 1 ? 1 : 2
        let rows = Int(ceil(Double(session.rounds.count) / Double(columns)))
        let width = (availableWidth - CGFloat(columns - 1) * 12) / CGFloat(columns)
        return CGFloat(rows) * (width * 6 / 7 + 70) + CGFloat(rows - 1) * 12
    }
}

struct ScoreStrip: View {
    let session: Session
    var body: some View {
        HStack(spacing: 12) {
            Label("CORAL", systemImage: Player.coral.symbol).foregroundStyle(Palette.coral)
            Text("\(session.wins(for: .coral))").font(.system(size: 20, weight: .black, design: .rounded))
            Spacer()
            Text("BOARDS WON").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
            Spacer()
            Text("\(session.wins(for: .gold))").font(.system(size: 20, weight: .black, design: .rounded))
            Label("GOLD", systemImage: Player.gold.symbol).foregroundStyle(Palette.gold)
        }.font(.system(size: 10, weight: .heavy)).padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Boards won: Coral \(session.wins(for: .coral)), Gold \(session.wins(for: .gold))")
    }
}

struct BoardCard: View {
    let round: BoardRound
    let duration: Double
    let now: Double
    let solo: Bool
    var compact = true
    var identifierPrefix = "board"
    var onFocus: (() -> Void)?
    var onDrop: (Int) -> Void
    private var color: Color { round.board.outcome.winner?.color ?? round.board.turn.color }
    private var canMove: Bool { !round.finished && !(solo && round.board.turn == .gold) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                Text(String(format: "%02d", round.id + 1)).font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 0)
                if !round.finished {
                    Countdown(remaining: round.remaining(at: now), duration: duration)
                } else {
                    Image(systemName: round.board.outcome.winner == nil ? "equal.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(color).font(.system(size: 18))
                }
                if let onFocus {
                    Button(action: onFocus) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold)).frame(width: 28, height: 30)
                    }.buttonStyle(.plain).foregroundStyle(Palette.muted)
                        .accessibilityLabel("Expand board \(round.id + 1)")
                        .accessibilityIdentifier("focus-board-\(round.id)")
                }
            }.frame(height: 30)
            BoardSurface(board: round.board, lastMove: round.lastMove?.move,
                         interactive: canMove, identifier: "\(identifierPrefix)-\(round.id)", onDrop: onDrop).equatable()
            HStack(spacing: 5) {
                Image(systemName: round.finished ? "flag.fill" : round.board.turn.symbol).font(.system(size: 7))
                Text(status).font(.system(size: compact ? 10 : 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text("\(round.board.moveCount)").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted)
                    .accessibilityLabel("\(round.board.moveCount) pieces played")
                    .accessibilityIdentifier("\(identifierPrefix)-\(round.id)-moves")
            }.foregroundStyle(color).frame(height: 17)
        }.padding(10).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(round.finished ? color.opacity(0.35) : .white.opacity(0.04), lineWidth: 1))
    }

    private var status: String {
        if let winner = round.board.outcome.winner { return "\(winner.name) wins!" }
        if round.finished { return "Draw. Well played." }
        if solo && round.board.turn == .gold { return "Gold is thinking…" }
        return "\(round.board.turn.name)’s turn"
    }
}

struct Countdown: View {
    let remaining: Double
    let duration: Double
    private var urgent: Bool { remaining <= min(3, duration * 0.25) }
    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().stroke(Palette.elevated, lineWidth: 2.5)
                Circle().trim(from: 0, to: min(1, max(0, remaining / duration)))
                    .stroke(urgent ? Palette.coral : Palette.lime, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }.frame(width: 17, height: 17)
            Text("\(Int(ceil(remaining)))s").font(.system(size: 13, weight: .bold, design: .monospaced))
                .monospacedDigit().foregroundStyle(urgent ? Palette.coral : Palette.ink).frame(minWidth: 24, alignment: .trailing)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(ceil(remaining))) seconds remaining")
    }
}

struct FocusedBoard: View {
    @Bindable var store: GameStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Board \((store.focusedBoard ?? 0) + 1)").font(.system(size: 30, weight: .black, design: .rounded))
                    Spacer()
                    Button("All boards") { store.focusedBoard = nil }.foregroundStyle(Palette.lime)
                        .accessibilityIdentifier("close-focus")
                }
                if let session = store.session,
                   let round = session.rounds.first(where: { $0.id == store.focusedBoard }) {
                    TimelineView(.animation(minimumInterval: 0.1, paused: round.finished)) { context in
                        BoardCard(round: round, duration: session.turnDuration,
                                  now: context.date.timeIntervalSince1970,
                                  solo: session.mode == .solo, compact: false, identifierPrefix: "focused",
                                  onDrop: { store.drop(column: $0, boardID: round.id) })
                    }
                    Text("The other clocks are still running.").font(.callout).foregroundStyle(Palette.muted)
                    HStack(spacing: 10) {
                        ForEach(session.rounds.filter { $0.id != round.id }) { other in
                            Button { store.focusedBoard = other.id } label: {
                                VStack(spacing: 8) {
                                    Text("\(other.id + 1)").font(.headline)
                                    Text(other.finished ? "Done" : other.board.turn.name).font(.caption2)
                                }.foregroundStyle(other.finished ? Palette.muted : other.board.turn.color)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel("Switch to board \(other.id + 1)")
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.foregroundStyle(Palette.ink).background(Palette.background).preferredColorScheme(.dark)
    }
}

struct ResultsPanel: View {
    let session: Session
    let rematch: () -> Void
    private var title: String {
        let coral = session.wins(for: .coral), gold = session.wins(for: .gold)
        if coral == gold { return "A perfectly matched rush." }
        return "\(coral > gold ? "Coral" : "Gold") takes the match."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "THAT’S A WRAP")
            Text(title).font(.system(size: 28, weight: .black, design: .rounded))
                .accessibilityIdentifier("match-result")
            Text("\(session.timeoutCount) autopilot moves. Ready for another round?")
                .font(.callout).foregroundStyle(Palette.muted)
            PrimaryButton(title: "Run it back", symbol: "arrow.clockwise", action: rematch)
                .accessibilityIdentifier("rematch")
        }.padding(22).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
