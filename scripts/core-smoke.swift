import ConnectCore
import Foundation

struct Seed: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

func check(_ condition: Bool, _ label: String) {
    precondition(condition, "FAILED: \(label)")
}

var rng = Seed()
for sequence in [[0, 6, 1, 6, 2, 5, 3], [0, 1, 0, 1, 0, 1, 0],
                 [0, 1, 1, 2, 4, 2, 2, 3, 4, 3, 5, 3, 3],
                 [6, 5, 5, 4, 2, 4, 4, 3, 2, 3, 1, 3, 3]] {
    var board = Board()
    for column in sequence { check(board.drop(in: column) != nil, "legal scripted move") }
    check(board.outcome.winner == .coral, "all four win directions")
    check(board.drop(in: 4) == nil, "terminal board refuses input")
}
var draw = Board()
for column in Array(repeating: [0, 2, 1, 3, 4, 6, 5], count: 6).flatMap({ $0 }) {
    check(draw.drop(in: column) != nil, "draw move")
}
check(draw.outcome == .draw, "42-cell draw")
var game = Session(boardCount: 4, turnDuration: 12, mode: .local, now: 100)
game.drop(column: 3, boardID: 0, at: 105, using: &rng)
check(game.rounds.map(\.deadline) == [117, 112, 112, 112], "independent deadlines")
check(game.advance(to: 112, using: &rng).count == 3, "three simultaneous timeouts")
check(game.advance(to: 112, using: &rng).isEmpty, "no duplicate timeouts")
let copy = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(game))
check(copy.isRestorable && copy.rounds == game.rounds, "save restoration")
var tie = Session(boardCount: 1, turnDuration: 8, mode: .local, now: 0)
let tieEvents = tie.drop(column: 3, boardID: 0, at: 8, using: &rng)
check(tieEvents.count == 1 && tieEvents[0].played.source == .timeout, "expiry wins tap tie")
var solo = Session(boardCount: 2, turnDuration: 12, mode: .solo, now: 0)
solo.drop(column: 3, boardID: 0, at: 1, using: &rng)
check(solo.drop(column: 4, boardID: 0, at: 1.1, using: &rng).isEmpty, "solo input ownership")
check(solo.advance(to: 1.65, using: &rng).first?.played.source == .computer, "computer response")
check(solo.rounds[1].board.moveCount == 0, "computer moves do not disturb other boards")
let randomStart = ContinuousClock.now
for _ in 0..<10_000 {
    var board = Board()
    var moves: [Move] = []
    while let column = board.legalColumns.randomElement(using: &rng) {
        moves.append(board.drop(in: column)!)
    }
    check(moves.count <= 42 && board.outcome != .playing, "random game termination")
    check(board.isConsistent(with: moves), "random game replay preserves gravity and turns")
}
print("10,000 randomized games passed in \(randomStart.duration(to: .now))")
let benchmarkStart = ContinuousClock.now
for _ in 0..<1_000 {
    var catchup = Session(boardCount: 4, turnDuration: 8, mode: .solo, now: 0)
    catchup.advance(to: 1_000_000, using: &rng)
    check(catchup.finished && catchup.isRestorable, "bounded four-board catch-up")
    check(catchup.advance(to: 2_000_000, using: &rng).isEmpty, "finished games stop timing")
}
print("1,000 complete four-board catch-ups passed in \(benchmarkStart.duration(to: .now))")
print("PASS: win directions, draws, independent timers, input races, computer play, saves, and randomized games")

var onlineHost = Session(boardCount: 4, turnDuration: 8, mode: .online, now: 100)
var replica = OnlineReplica()
let matchID = UUID()
var revision = 0
for step in 0...400 {
    let now = 100 + Double(step)
    onlineHost.advance(to: now, using: &rng)
    for round in onlineHost.rounds where !round.finished && step % 3 == 0 {
        onlineHost.submitMove(player: round.board.turn,
                              column: round.board.computerColumn(using: &rng)!, boardID: round.id,
                              expectedMoveCount: round.board.moveCount, at: now, using: &rng)
    }
    revision += 1
    var packet = OnlinePacket(kind: .state)
    packet.matchID = matchID
    packet.revision = revision
    packet.session = onlineHost
    packet.sentAt = now
    let data = try JSONEncoder().encode(packet)
    check(replica.accept(OnlinePacket.decode(data)!, receivedAt: now - 20), "guest accepts current snapshot")
    check(replica.session!.rounds == onlineHost.rounds, "host and guest match")
    check(!replica.accept(packet, receivedAt: now - 20), "guest rejects duplicate revision")
    if onlineHost.finished { break }
}
check(onlineHost.finished && replica.session!.finished, "online match completes on both peers")
print("PASS: serialized four-board online match, clock skew, and duplicate snapshot rejection")
