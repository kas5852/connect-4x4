import Foundation

public enum PlayMode: String, CaseIterable, Codable, Sendable {
    case solo, local, online
    public var title: String {
        switch self { case .solo: return "Solo rush"; case .local: return "Local"; case .online: return "Online" }
    }
}

public enum MoveSource: String, Codable, Sendable { case touch, timeout, computer }

public struct PlayedMove: Equatable, Codable, Sendable {
    public let move: Move
    public let source: MoveSource
    public let time: TimeInterval
}

public struct BoardRound: Equatable, Codable, Sendable, Identifiable {
    public let id: Int
    public internal(set) var board = Board()
    public internal(set) var deadline: TimeInterval
    public internal(set) var computerDue: TimeInterval?
    public internal(set) var history: [PlayedMove] = []
    public var lastMove: PlayedMove? { history.last }
    public var timeoutCount: Int { history.filter { $0.source == .timeout }.count }
    public var finished: Bool { board.outcome != .playing }
    public func remaining(at time: TimeInterval) -> TimeInterval {
        finished ? 0 : max(0, deadline - time)
    }
}

public struct GameEvent: Equatable, Sendable {
    public let boardID: Int
    public let played: PlayedMove
}

/// Deadlines are absolute, not accumulated timer ticks. At most 42 moves per
/// board can be caught up, even after days away. Expiry wins a tie with a tap.
public struct Session: Codable, Sendable {
    public let mode: PlayMode
    public let turnDuration: TimeInterval
    public let startedAt: TimeInterval
    public private(set) var lastAdvancedAt: TimeInterval
    public private(set) var rounds: [BoardRound]

    public init(boardCount: Int, turnDuration: TimeInterval, mode: PlayMode, now: TimeInterval) {
        let duration = turnDuration.isFinite ? min(60, max(2, turnDuration)) : 12
        let start = now.isFinite ? now : 0
        self.mode = mode
        self.turnDuration = duration
        self.startedAt = start
        self.lastAdvancedAt = startedAt
        self.rounds = (0..<min(4, max(1, boardCount))).map {
            BoardRound(id: $0, deadline: start + duration)
        }
    }

    public var finished: Bool { rounds.allSatisfy(\.finished) }
    public var timeoutCount: Int { rounds.reduce(0) { $0 + $1.timeoutCount } }
    public func wins(for player: Player) -> Int {
        rounds.filter { $0.board.outcome.winner == player }.count
    }

    @discardableResult
    public mutating func advance<R: RandomNumberGenerator>(
        to now: TimeInterval, using rng: inout R
    ) -> [GameEvent] {
        guard now.isFinite else { return [] }
        let time = max(now, lastAdvancedAt)
        lastAdvancedAt = time
        var events: [GameEvent] = []
        for index in rounds.indices {
            while !rounds[index].finished {
                let round = rounds[index]
                let computerTime = round.computerDue ?? .infinity
                let due = min(round.deadline, computerTime)
                guard due <= time else { break }
                let source: MoveSource = computerTime < round.deadline ? .computer : .timeout
                let column: Int?
                if source == .computer {
                    column = round.board.computerColumn(using: &rng)
                } else {
                    column = round.board.legalColumns.randomElement(using: &rng)
                }
                guard let column, let played = apply(column: column, index: index, time: due, source: source)
                else { break }
                events.append(GameEvent(boardID: round.id, played: played))
            }
        }
        return events
    }

    /// Returns catch-up events as well as the tap. No late tap can affect a new turn.
    @discardableResult
    public mutating func drop<R: RandomNumberGenerator>(
        column: Int, boardID: Int, at now: TimeInterval, using rng: inout R
    ) -> [GameEvent] {
        guard now.isFinite else { return [] }
        guard let index = rounds.firstIndex(where: { $0.id == boardID }) else {
            return advance(to: now, using: &rng)
        }
        let expectedMoveCount = rounds[index].board.moveCount
        var events = advance(to: now, using: &rng)
        guard rounds[index].board.moveCount == expectedMoveCount,
              !(mode == .solo && rounds[index].board.turn == .gold),
              let played = apply(column: column, index: index, time: lastAdvancedAt, source: .touch)
        else { return events }
        events.append(GameEvent(boardID: boardID, played: played))
        return events
    }

    private mutating func apply(column: Int, index: Int, time: TimeInterval, source: MoveSource) -> PlayedMove? {
        guard let move = rounds[index].board.drop(in: column) else { return nil }
        let played = PlayedMove(move: move, source: source, time: time)
        rounds[index].history.append(played)
        rounds[index].deadline = time + turnDuration
        rounds[index].computerDue = mode == .solo && rounds[index].board.turn == .gold && !rounds[index].finished
            ? time + min(0.65, turnDuration * 0.25) : nil
        return played
    }

    /// The online host accepts arrival time, never a client-provided timestamp.
    /// Expected move counts prevent retransmitted/stale intents playing a later turn.
    @discardableResult
    public mutating func submitMove<R: RandomNumberGenerator>(
        player: Player, column: Int, boardID: Int, expectedMoveCount: Int,
        at now: TimeInterval, using rng: inout R
    ) -> [GameEvent] {
        guard let round = rounds.first(where: { $0.id == boardID }),
              round.board.turn == player, round.board.moveCount == expectedMoveCount else {
            return advance(to: now, using: &rng)
        }
        return drop(column: column, boardID: boardID, at: now, using: &rng)
    }

    /// Saves are local and untrusted. Reject malformed histories or timer metadata.
    public var isRestorable: Bool {
        guard (1...4).contains(rounds.count), (2...60).contains(turnDuration),
              startedAt.isFinite, lastAdvancedAt.isFinite, lastAdvancedAt >= startedAt,
              rounds.map(\.id) == Array(rounds.indices) else { return false }
        return rounds.allSatisfy { round in
            guard round.deadline.isFinite, round.deadline >= startedAt,
                  round.board.isConsistent(with: round.history.map(\.move)) else { return false }
            var previous = startedAt
            for entry in round.history {
                guard entry.time.isFinite, entry.time >= previous,
                      entry.time <= lastAdvancedAt else { return false }
                previous = entry.time
            }
            guard round.deadline == previous + turnDuration else { return false }
            let needsComputer = mode == .solo && round.board.turn == .gold && !round.finished
            if needsComputer {
                return round.computerDue == previous + min(0.65, turnDuration * 0.25)
            }
            return round.computerDue == nil
        }
    }
}
