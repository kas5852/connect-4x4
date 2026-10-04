import XCTest
@testable import ConnectCore

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

final class BoardTests: XCTestCase {
    func play(_ columns: [Int]) -> Board {
        var board = Board()
        for column in columns { XCTAssertNotNil(board.drop(in: column)) }
        return board
    }

    func testGravityFullColumnAndInvalidInput() {
        var board = Board()
        for row in (0..<6).reversed() { XCTAssertEqual(board.drop(in: 3)?.row, row) }
        let unchanged = board
        XCTAssertNil(board.drop(in: 3))
        XCTAssertNil(board.drop(in: -1))
        XCTAssertNil(board.drop(in: 7))
        XCTAssertEqual(board, unchanged)
        XCTAssertEqual(board.legalColumns.count, 6)
    }

    func testHorizontalAndVerticalWins() {
        for sequence in [[0, 6, 1, 6, 2, 5, 3], [0, 1, 0, 1, 0, 1, 0]] {
            var board = play(sequence)
            XCTAssertEqual(board.outcome.winner, .coral)
            XCTAssertEqual(board.outcome.winningCells.count, 4)
            XCTAssertEqual(board.legalColumns, [])
            XCTAssertNil(board.drop(in: 4))
        }
    }

    func testBothDiagonalWinDirections() {
        let ascending = [0, 1, 1, 2, 4, 2, 2, 3, 4, 3, 5, 3, 3]
        for sequence in [ascending, ascending.map { 6 - $0 }] {
            let board = play(sequence)
            XCTAssertEqual(board.outcome.winner, .coral)
            XCTAssertEqual(board.outcome.winningCells.count, 4)
        }
    }

    func testComputerTakesWinAndBlocksImmediateThreat() {
        var rng = SeededGenerator(state: 7)
        let winning = play([6, 0, 6, 1, 5, 2, 4])
        XCTAssertEqual(winning.turn, .gold)
        XCTAssertEqual(winning.computerColumn(using: &rng), 3)
        let threat = play([0, 6, 1, 6, 2])
        XCTAssertEqual(threat.computerColumn(using: &rng), 3)
    }

    func testDrawAndTerminalImmutability() {
        // Construct a checker pattern of two-piece bands without any four-in-a-row.
        var board = Board()
        for column in Array(repeating: [0, 2, 1, 3, 4, 6, 5], count: 6).flatMap({ $0 }) {
            XCTAssertNotNil(board.drop(in: column))
        }
        XCTAssertEqual(board.outcome, .draw)
        XCTAssertEqual(board.moveCount, 42)
        XCTAssertNil(board.drop(in: 0))
    }

    func testTenThousandRandomGamesPreserveGravityAndStop() {
        var rng = SeededGenerator(state: 123)
        for _ in 0..<10_000 {
            var board = Board()
            var moves: [Move] = []
            while let column = board.legalColumns.randomElement(using: &rng) {
                moves.append(board.drop(in: column)!)
            }
            XCTAssertLessThanOrEqual(moves.count, 42)
            XCTAssertNotEqual(board.outcome, .playing)
            XCTAssertTrue(board.isConsistent(with: moves))
        }
    }
}
