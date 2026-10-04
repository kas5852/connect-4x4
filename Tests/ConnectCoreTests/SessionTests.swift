import XCTest
@testable import ConnectCore

final class SessionTests: XCTestCase {
    func testFourIndependentDeadlines() {
        var game = Session(boardCount: 4, turnDuration: 12, mode: .local, now: 100)
        var rng = SeededGenerator(state: 1)
        game.drop(column: 2, boardID: 0, at: 105, using: &rng)
        XCTAssertEqual(game.rounds.map(\.deadline), [117, 112, 112, 112])
        let events = game.advance(to: 112, using: &rng)
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events.allSatisfy { $0.played.source == .timeout })
        XCTAssertEqual(game.rounds.map { $0.board.moveCount }, [1, 1, 1, 1])
        XCTAssertTrue(game.isRestorable)
    }

    func testDeadlineWinsTieAndTimeoutIsNeverDuplicated() {
        var game = Session(boardCount: 1, turnDuration: 8, mode: .local, now: 0)
        var rng = SeededGenerator(state: 1)
        let events = game.drop(column: 3, boardID: 0, at: 8, using: &rng)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.played.source, .timeout)
        XCTAssertEqual(game.rounds[0].board.moveCount, 1)
        XCTAssertTrue(game.advance(to: 8, using: &rng).isEmpty)
        XCTAssertEqual(game.rounds[0].deadline, 16)
    }

    func testBackgroundCatchupAndRoundTrip() throws {
        var game = Session(boardCount: 4, turnDuration: 12, mode: .local, now: 0)
        var rng = SeededGenerator(state: 12)
        game.advance(to: 48, using: &rng)
        XCTAssertEqual(game.rounds.map { $0.board.moveCount }, [4, 4, 4, 4])
        let copy = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(copy.rounds, game.rounds)
        XCTAssertTrue(copy.isRestorable)
        let events = game.advance(to: 1_000_000, using: &rng)
        XCTAssertLessThanOrEqual(events.count, 4 * 38)
        XCTAssertTrue(game.finished)
        XCTAssertTrue(game.advance(to: 2_000_000, using: &rng).isEmpty)
        XCTAssertTrue(game.isRestorable)
    }

    func testSoloOpponentAndInputOwnership() {
        var game = Session(boardCount: 2, turnDuration: 12, mode: .solo, now: 0)
        var rng = SeededGenerator(state: 8)
        game.drop(column: 3, boardID: 0, at: 1, using: &rng)
        XCTAssertEqual(game.rounds[0].board.turn, .gold)
        XCTAssertTrue(game.drop(column: 4, boardID: 0, at: 1.1, using: &rng).isEmpty)
        XCTAssertTrue(game.advance(to: 1.64, using: &rng).isEmpty)
        let events = game.advance(to: 1.65, using: &rng)
        XCTAssertEqual(events.first?.played.source, .computer)
        XCTAssertEqual(game.rounds[0].board.turn, .coral)
        XCTAssertEqual(game.rounds[1].board.moveCount, 0)
        XCTAssertTrue(game.isRestorable)
    }

    func testTimeoutRandomnessOnlySelectsLegalColumns() {
        var game = Session(boardCount: 1, turnDuration: 8, mode: .local, now: 0)
        var rng = SeededGenerator(state: 5)
        for step in 1...6 { game.drop(column: 3, boardID: 0, at: Double(step), using: &rng) }
        let events = game.advance(to: 14, using: &rng)
        XCTAssertEqual(events.count, 1)
        XCTAssertNotEqual(events[0].played.move.column, 3)
        XCTAssertEqual(game.rounds[0].board.moveCount, 7)
    }

    func testFinishedBoardDoesNotKeepTimingOut() {
        var game = Session(boardCount: 2, turnDuration: 12, mode: .local, now: 0)
        var rng = SeededGenerator(state: 2)
        for (i, column) in [0, 6, 1, 6, 2, 5, 3].enumerated() {
            game.drop(column: column, boardID: 0, at: Double(i), using: &rng)
        }
        XCTAssertTrue(game.rounds[0].finished)
        XCTAssertFalse(game.finished)
        game.advance(to: 100, using: &rng)
        XCTAssertEqual(game.rounds[0].board.moveCount, 7)
        XCTAssertTrue(game.isRestorable)
    }

    func testCorruptSaveIsRejected() throws {
        let game = Session(boardCount: 1, turnDuration: 12, mode: .solo, now: 0)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as! [String: Any]
        json["turnDuration"] = 0
        let corrupt = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(corrupt.isRestorable)
        json["turnDuration"] = 12
        var rounds = json["rounds"] as! [[String: Any]]
        rounds[0]["deadline"] = 13
        json["rounds"] = rounds
        let badDeadline = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(badDeadline.isRestorable)
    }

    func testBackwardsClockAndNonFiniteInputDoNotDuplicateMoves() {
        var game = Session(boardCount: 1, turnDuration: 12, mode: .local, now: 100)
        var rng = SeededGenerator(state: 4)
        game.advance(to: 112, using: &rng)
        XCTAssertTrue(game.advance(to: 101, using: &rng).isEmpty)
        XCTAssertTrue(game.drop(column: 1, boardID: 0, at: .nan, using: &rng).isEmpty)
        XCTAssertTrue(game.advance(to: .infinity, using: &rng).isEmpty)
        XCTAssertEqual(game.rounds[0].board.moveCount, 1)
    }

    func testWholeFourBoardMatchWithMixedTapsAndTimeouts() {
        var game = Session(boardCount: 4, turnDuration: 8, mode: .solo, now: 0)
        var rng = SeededGenerator(state: 42)
        for step in 1...600 {
            let time = Double(step) * 0.5
            game.advance(to: time, using: &rng)
            if step % 5 == 0 {
                for round in game.rounds where !round.finished && round.board.turn == .coral {
                    game.drop(column: round.board.computerColumn(using: &rng)!, boardID: round.id, at: time, using: &rng)
                }
            }
            if game.finished { break }
        }
        XCTAssertTrue(game.finished)
        XCTAssertTrue(game.isRestorable)
        XCTAssertLessThanOrEqual(game.rounds.reduce(0) { $0 + $1.board.moveCount }, 168)
    }

    func testFourBoardCatchupPerformance() {
        measure {
            var rng = SeededGenerator(state: 101)
            for _ in 0..<100 {
                var game = Session(boardCount: 4, turnDuration: 8, mode: .solo, now: 0)
                game.advance(to: 10_000, using: &rng)
                XCTAssertTrue(game.finished)
            }
        }
    }
}
