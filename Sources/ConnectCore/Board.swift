import Foundation

public enum Player: String, Codable, Sendable, CaseIterable {
    case coral, gold
    public var opponent: Player { self == .coral ? .gold : .coral }
    public var name: String { self == .coral ? "Coral" : "Gold" }
}

public struct Move: Equatable, Codable, Sendable {
    public let column: Int
    public let row: Int
    public let player: Player
    public var index: Int { row * Board.columns + column }
}

public enum Outcome: Equatable, Codable, Sendable {
    case playing
    case won(Player, cells: [Int])
    case draw

    public var winner: Player? {
        if case let .won(player, _) = self { return player }
        return nil
    }
    public var winningCells: [Int] {
        if case let .won(_, cells) = self { return cells }
        return []
    }
}

/// Row zero is at the top. All mutations enforce gravity and terminal outcomes.
public struct Board: Equatable, Codable, Sendable {
    public static let columns = 7
    public static let rows = 6
    public private(set) var cells: [Player?] = Array(repeating: nil, count: 42)
    public private(set) var turn: Player = .coral
    public private(set) var outcome: Outcome = .playing
    public private(set) var moveCount = 0

    public init() {}
    public subscript(row: Int, column: Int) -> Player? { cells[row * Self.columns + column] }
    public var legalColumns: [Int] {
        guard outcome == .playing else { return [] }
        return (0..<Self.columns).filter { cells[$0] == nil }
    }

    @discardableResult
    public mutating func drop(in column: Int) -> Move? {
        guard (0..<Self.columns).contains(column), outcome == .playing,
              let row = (0..<Self.rows).reversed().first(where: { self[$0, column] == nil })
        else { return nil }
        let move = Move(column: column, row: row, player: turn)
        cells[move.index] = turn
        moveCount += 1
        let line = winningLine(through: move)
        if line.count >= 4 { outcome = .won(turn, cells: line) }
        else if moveCount == 42 { outcome = .draw }
        else { turn = turn.opponent }
        return move
    }

    private func winningLine(through move: Move) -> [Int] {
        for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            var line = [move.index]
            for sign in [-1, 1] {
                var r = move.row + dr * sign
                var c = move.column + dc * sign
                while (0..<Self.rows).contains(r), (0..<Self.columns).contains(c),
                      self[r, c] == move.player {
                    line.append(r * Self.columns + c)
                    r += dr * sign
                    c += dc * sign
                }
            }
            if line.count >= 4 { return line.sorted() }
        }
        return []
    }

    /// Replay proves gravity, alternating turns, and the stored outcome together.
    /// Session restoration uses its move log rather than trusting arbitrary JSON cells.
    public func isConsistent(with moves: [Move]) -> Bool {
        var replay = Board()
        for expected in moves {
            guard replay.drop(in: expected.column) == expected else { return false }
        }
        return replay == self
    }

    /// A fast tactical opponent: win, block, then favor the center.
    public func computerColumn<R: RandomNumberGenerator>(using rng: inout R) -> Int? {
        let legal = legalColumns
        for column in legal {
            var copy = self
            copy.drop(in: column)
            if copy.outcome.winner == turn { return column }
        }
        for column in legal {
            var copy = self
            copy.turn = turn.opponent
            copy.drop(in: column)
            if copy.outcome.winner == turn.opponent { return column }
        }
        let weighted = legal.flatMap { column in
            Array(repeating: column, count: 4 - abs(3 - column))
        }
        return weighted.randomElement(using: &rng)
    }
}
