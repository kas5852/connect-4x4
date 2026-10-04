import XCTest
@testable import ConnectCore

final class OnlineTests: XCTestCase {
    func state(_ session: Session, id: UUID, revision: Int, sentAt: Double) -> OnlinePacket {
        var packet = OnlinePacket(kind: .state)
        packet.matchID = id
        packet.revision = revision
        packet.session = session
        packet.sentAt = sentAt
        return packet
    }

    func testWrongPlayerDuplicateIntentAndExpiredIntentCannotMove() {
        var game = Session(boardCount: 4, turnDuration: 8, mode: .online, now: 0)
        var rng = SeededGenerator(state: 44)
        XCTAssertTrue(game.submitMove(player: .gold, column: 2, boardID: 0, expectedMoveCount: 0,
                                      at: 1, using: &rng).isEmpty)
        game.submitMove(player: .coral, column: 3, boardID: 0, expectedMoveCount: 0, at: 2, using: &rng)
        XCTAssertTrue(game.submitMove(player: .coral, column: 3, boardID: 0, expectedMoveCount: 0,
                                      at: 2.1, using: &rng).isEmpty)
        game.submitMove(player: .gold, column: 4, boardID: 0, expectedMoveCount: 1, at: 3, using: &rng)
        XCTAssertTrue(game.submitMove(player: .coral, column: 3, boardID: 0, expectedMoveCount: 0,
                                      at: 4, using: &rng).isEmpty)
        let events = game.submitMove(player: .coral, column: 3, boardID: 0, expectedMoveCount: 2,
                                    at: 11, using: &rng)
        XCTAssertTrue(events.allSatisfy { $0.played.source == .timeout })
        XCTAssertEqual(game.rounds[0].board.moveCount, 3)
        XCTAssertTrue(game.isRestorable)
    }

    func testFractionalEpochDeadlinesSurviveWireEncoding() throws {
        let epoch = 1_791_076_497.20559
        var game = Session(boardCount: 4, turnDuration: 12, mode: .online, now: epoch)
        var rng = SeededGenerator(state: 2026)
        game.submitMove(player: .coral, column: 3, boardID: 0, expectedMoveCount: 0,
                        at: epoch + 1.123456, using: &rng)
        game.submitMove(player: .gold, column: 2, boardID: 0, expectedMoveCount: 1,
                        at: epoch + 2.987654, using: &rng)
        var replica = OnlineReplica()
        let packet = state(game, id: UUID(), revision: 1, sentAt: epoch + 3.5)
        let wire = OnlinePacket.decode(try JSONEncoder().encode(packet))!
        XCTAssertTrue(replica.accept(wire, receivedAt: epoch - 20))
        XCTAssertEqual(replica.session?.rounds, game.rounds)
    }

    func testReplicaRejectsOldForeignInvalidAndUnsupportedPackets() {
        let game = Session(boardCount: 4, turnDuration: 12, mode: .online, now: 100)
        let id = UUID()
        var replica = OnlineReplica()
        let first = state(game, id: id, revision: 2, sentAt: 101)
        XCTAssertTrue(replica.accept(first, receivedAt: 81))
        XCTAssertEqual(replica.initialClockOffset, 20)
        XCTAssertFalse(replica.accept(first, receivedAt: 82))
        XCTAssertFalse(replica.accept(state(game, id: UUID(), revision: 3, sentAt: 102), receivedAt: 82))
        var version = state(game, id: id, revision: 3, sentAt: 102)
        version.version = 2
        XCTAssertFalse(replica.accept(version, receivedAt: 82))
        let local = Session(boardCount: 1, turnDuration: 12, mode: .local, now: 100)
        XCTAssertFalse(replica.accept(state(local, id: id, revision: 3, sentAt: 102), receivedAt: 82))
        XCTAssertNil(OnlinePacket.decode(Data(repeating: 0, count: 65 * 1024)))
        XCTAssertNil(OnlinePacket.decode(Data("not JSON".utf8)))
    }

    func testSerializedHostGuestMatchEndToEndWithClockSkewAndRematch() throws {
        var host = Session(boardCount: 4, turnDuration: 8, mode: .online, now: 100)
        var guest = OnlineReplica()
        var rng = SeededGenerator(state: 991)
        let id = UUID()
        var revision = 0
        func deliver(now: Double) throws {
            revision += 1
            let packet = state(host, id: id, revision: revision, sentAt: now)
            let data = try JSONEncoder().encode(packet)
            XCTAssertLessThan(data.count, 64 * 1024)
            XCTAssertTrue(guest.accept(OnlinePacket.decode(data)!, receivedAt: now - 20))
            XCTAssertEqual(guest.session?.rounds, host.rounds)
        }
        try deliver(now: 100)
        for step in 1...400 {
            let now = 100 + Double(step)
            host.advance(to: now, using: &rng)
            for round in host.rounds where !round.finished && step % 3 == 0 {
                var intent = OnlinePacket(kind: .move)
                intent.matchID = id
                intent.boardID = round.id
                intent.column = round.board.computerColumn(using: &rng)
                intent.expectedMoveCount = round.board.moveCount
                let wire = OnlinePacket.decode(try JSONEncoder().encode(intent))!
                host.submitMove(player: round.board.turn, column: wire.column!, boardID: wire.boardID!,
                                expectedMoveCount: wire.expectedMoveCount!, at: now, using: &rng)
            }
            try deliver(now: now)
            if host.finished { break }
        }
        XCTAssertTrue(host.finished)
        XCTAssertTrue(guest.session!.finished)
        XCTAssertEqual(guest.session!.wins(for: .coral), host.wins(for: .coral))
        let old = state(host, id: id, revision: revision, sentAt: 500)
        host = Session(boardCount: 4, turnDuration: 8, mode: .online, now: 501)
        try deliver(now: 501)
        XCTAssertEqual(guest.session!.rounds[0].board.moveCount, 0)
        XCTAssertFalse(guest.accept(old, receivedAt: 481))
    }
}
