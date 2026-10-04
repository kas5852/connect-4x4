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
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var active = true
    @ObservationIgnored private let defaults: UserDefaults?
    private static let saveKey = "connect4x4.session.v1"

    public init(restore: Bool = true) {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        defaults = restore && !testing ? .standard : nil
        if let data = defaults?.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(Session.self, from: data), saved.isRestorable {
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
    }

    public init(preview session: Session) {
        defaults = nil
        self.session = session
        boardCount = session.rounds.count
        turnSeconds = session.turnDuration
        mode = session.mode
        active = false
    }

    public func start() {
        session = Session(boardCount: boardCount, turnDuration: turnSeconds, mode: mode,
                          now: Date.now.timeIntervalSince1970)
        focusedBoard = nil
        notice = nil
        save()
        schedule()
    }

    public func drop(column: Int, boardID: Int) {
        guard var game = session else { return }
        let events = game.drop(column: column, boardID: boardID,
                               at: Date.now.timeIntervalSince1970, using: &rng)
        if !events.isEmpty {
            session = game
            feedback += 1
            notice = events.contains(where: { $0.played.source == .timeout })
                ? "Time ran out. Autopilot dropped a random piece." : nil
            save()
        } else if let round = game.rounds.first(where: { $0.id == boardID }), !round.finished {
            notice = game.mode == .solo && round.board.turn == .gold
                ? "Gold is thinking. Keep an eye on your other boards."
                : "That column is full. Try another."
        }
        schedule()
    }

    public func setActive(_ isActive: Bool) {
        active = isActive
        timerTask?.cancel()
        if isActive { process(); schedule() } else { save() }
    }

    public func leave() {
        timerTask?.cancel()
        session = nil
        focusedBoard = nil
        defaults?.removeObject(forKey: Self.saveKey)
        notice = nil
    }

    private func process() {
        guard var game = session else { return }
        let events = game.advance(to: Date.now.timeIntervalSince1970, using: &rng)
        guard !events.isEmpty else { return }
        session = game
        if events.contains(where: { $0.played.source == .timeout }) {
            notice = "Autopilot moved on \(Set(events.filter { $0.played.source == .timeout }.map(\.boardID)).count) board(s)."
        }
        save()
    }

    /// One sleeping task for the next actual event, not four polling timers.
    private func schedule() {
        timerTask?.cancel()
        guard active, let game = session, !game.finished else { return }
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
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        defaults?.set(data, forKey: Self.saveKey)
    }
}
