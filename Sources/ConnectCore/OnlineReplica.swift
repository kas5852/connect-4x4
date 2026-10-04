import Foundation

/// The guest consumes full authoritative snapshots. Old revisions, another
/// match's packets, malformed saves, and unsupported versions never change it.
public struct OnlineReplica: Sendable {
    public private(set) var session: Session?
    public private(set) var matchID: UUID?
    public private(set) var revision = 0
    public private(set) var initialClockOffset: TimeInterval = 0
    public init() {}

    @discardableResult
    public mutating func accept(_ packet: OnlinePacket, receivedAt localTime: TimeInterval) -> Bool {
        guard packet.version == 1, packet.kind == .state, localTime.isFinite,
              let id = packet.matchID, matchID == nil || matchID == id,
              let next = packet.revision, next > revision,
              let game = packet.session, game.mode == .online, game.isRestorable,
              let sent = packet.sentAt, sent.isFinite else { return false }
        if matchID == nil { initialClockOffset = sent - localTime }
        matchID = id
        revision = next
        session = game
        return true
    }
}
