import ConnectCore
import Foundation
import Observation

@MainActor @Observable
public final class GameStore {
    public var boardCount = 4
    public var turnSeconds: Double = 12
    public var mode: PlayMode = .solo
    public private(set) var session: Session?
    public var focusedBoard: Int?
    public var soundlessHaptics = true
    public private(set) var feedback = 0
    public private(set) var notice: String?
    public let online = OnlineClient()
    public private(set) var pendingBoards: Set<Int> = []
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var active = true
    @ObservationIgnored private let defaults: UserDefaults?
    private static let saveKey = "connect4x4.session.v1"

    public init(restore: Bool = true) {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        defaults = restore && !testing ? .standard : nil
        if let data = defaults?.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(Session.self, from: data), saved.isRestorable, saved.mode != .online {
            session = saved
            boardCount = saved.rounds.count
            turnSeconds = saved.turnDuration
            mode = saved.mode
        }
        if testing {
            session = nil
            boardCount = 4
            mode = .local
        }
        if ProcessInfo.processInfo.arguments.contains("--fast-timers") { turnSeconds = 2 }
        if ProcessInfo.processInfo.arguments.contains("--long-timers") { turnSeconds = 60 }
        configureOnline()
    }

    public init(preview session: Session) {
        defaults = nil
        self.session = session
        boardCount = session.rounds.count
        turnSeconds = session.turnDuration
        mode = session.mode
        active = false
        configureOnline()
    }

    public func start() {
        trace("start mode=\(mode.rawValue) boards=\(boardCount)")
        if mode == .online {
            if online.connected && online.isHost { beginOnline() }
            else { online.findMatch() }
            return
        }
        session = Session(boardCount: boardCount, turnDuration: turnSeconds, mode: mode,
                          now: Date.now.timeIntervalSince1970)
        focusedBoard = nil
        notice = nil
        save()
        schedule()
    }

    public func drop(column: Int, boardID: Int) {
        guard var game = session else { return }
        if game.mode == .online {
            guard online.connected, let round = game.rounds.first(where: { $0.id == boardID }),
                  round.board.turn == online.localPlayer, !round.finished else { return }
            if !online.isHost {
                guard !pendingBoards.contains(boardID), round.board.legalColumns.contains(column) else { return }
                pendingBoards.insert(boardID)
                online.requestMove(column: column, boardID: boardID, expectedMoveCount: round.board.moveCount)
                return
            }
        }
        let events = game.drop(column: column, boardID: boardID,
                               at: Date.now.timeIntervalSince1970, using: &rng)
        if !events.isEmpty {
            session = game
            feedback += 1
            notice = events.contains(where: { $0.played.source == .timeout })
                ? "Time ran out. Autopilot dropped a random piece." : nil
            save()
            if game.mode == .online { online.publish(game) }
        } else if let round = game.rounds.first(where: { $0.id == boardID }), !round.finished {
            notice = game.mode == .solo && round.board.turn == .gold
                ? "Gold is thinking. Keep an eye on your other boards."
                : "That column is full. Try another."
        }
        schedule()
    }

    public func setActive(_ isActive: Bool) {
        trace("active=\(isActive)")
        active = isActive
        timerTask?.cancel()
        if isActive { process(); schedule() } else { save() }
    }

    public func enterBackground() {
        if online.connected { online.disconnect(message: "Online match ended because a player left the app.") }
    }

    public func displayTime(_ local: TimeInterval) -> TimeInterval {
        session?.mode == .online && !online.isHost ? local + online.clockOffset : local
    }

    public func leave() {
        if online.connected { online.disconnect() }
        timerTask?.cancel()
        session = nil
        focusedBoard = nil
        defaults?.removeObject(forKey: Self.saveKey)
        notice = nil
        pendingBoards.removeAll()
    }

    private func process() {
        guard var game = session else { return }
        if game.mode == .online && !online.isHost { return }
        let events = game.advance(to: Date.now.timeIntervalSince1970, using: &rng)
        trace("process events=\(events.count)")
        guard !events.isEmpty else { return }
        session = game
        if events.contains(where: { $0.played.source == .timeout }) {
            notice = "Autopilot moved on \(Set(events.filter { $0.played.source == .timeout }.map(\.boardID)).count) board(s)."
        }
        save()
        if game.mode == .online { online.publish(game) }
    }

    /// One sleeping task for the next actual event, not four polling timers.
    private func schedule() {
        trace("schedule active=\(active) mode=\(session?.mode.rawValue ?? "none")")
        timerTask?.cancel()
        guard active, let game = session, !game.finished else { return }
        guard game.mode != .online || online.isHost else { return }
        let next = game.rounds.filter { !$0.finished }.map {
            min($0.deadline, $0.computerDue ?? .infinity)
        }.min()!
        let seconds = min(60, max(0.01, next - Date.now.timeIntervalSince1970))
        timerTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.process()
            self.schedule()
        }
    }

    private func save() {
        guard let session, session.mode != .online, let data = try? JSONEncoder().encode(session) else { return }
        defaults?.set(data, forKey: Self.saveKey)
    }

    private func beginOnline() {
        session = Session(boardCount: boardCount, turnDuration: turnSeconds, mode: .online,
                          now: Date.now.timeIntervalSince1970)
        focusedBoard = nil
        pendingBoards.removeAll()
        notice = "You’re Coral. \(online.peerName) is Gold."
        defaults?.removeObject(forKey: Self.saveKey)
        if let session { online.publish(session) }
        schedule()
    }

    private func configureOnline() {
        online.onReady = { [weak self] host in
            guard let self else { return }
            self.mode = .online
            if host { self.beginOnline() }
        }
        online.onState = { [weak self] game in
            guard let self else { return }
            self.session = game
            self.boardCount = game.rounds.count
            self.turnSeconds = game.turnDuration
            self.pendingBoards.removeAll()
            self.notice = "You’re Gold. \(self.online.peerName) is Coral."
            self.defaults?.removeObject(forKey: Self.saveKey)
        }
        online.onMove = { [weak self] column, boardID, expected in
            guard let self, var game = self.session, self.online.isHost else { return }
            game.submitMove(player: .gold, column: column, boardID: boardID,
                            expectedMoveCount: expected, at: Date.now.timeIntervalSince1970, using: &self.rng)
            self.session = game
            // A snapshot also acknowledges a rejected stale intent.
            self.online.publish(game)
            self.schedule()
        }
        online.onRequestState = { [weak self] in
            guard let self, let session = self.session else { return }
            self.online.publish(session)
        }
        online.onDisconnect = { [weak self] in
            guard let self else { return }
            if self.session?.mode == .online { self.session = nil }
            self.timerTask?.cancel()
            self.pendingBoards.removeAll()
            self.focusedBoard = nil
        }
    }

    private func trace(_ message: String) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            print("[connect-tests] \(message)")
        }
        #endif
    }
}
