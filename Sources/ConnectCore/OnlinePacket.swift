import Foundation

/// Small versioned messages carried over Game Center's reliable match transport.
/// One peer owns the engine. The other sends intents, never local timeout results.
public struct OnlinePacket: Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case ready, state, move, ping, pong, goodbye }
    public var version = 1
    public var kind: Kind
    public var matchID: UUID?
    public var revision: Int?
    public var session: Session?
    public var sentAt: TimeInterval?
    public var boardID: Int?
    public var column: Int?
    public var expectedMoveCount: Int?
    public var pingID: UUID?
    public var clientTime: TimeInterval?
    public var message: String?

    public init(kind: Kind) { self.kind = kind }

    public static func decode(_ data: Data) -> OnlinePacket? {
        guard data.count <= 64 * 1024,
              let packet = try? JSONDecoder().decode(Self.self, from: data), packet.version == 1
        else { return nil }
        return packet
    }
}
