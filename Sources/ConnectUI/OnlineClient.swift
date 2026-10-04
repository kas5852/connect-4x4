import ConnectCore
import Foundation
import Observation
import SwiftUI
#if os(iOS)
import GameKit
import UIKit
#endif

@MainActor @Observable
public final class OnlineClient: NSObject {
    public private(set) var status = "Play a friend live with Game Center."
    public private(set) var error: String?
    public private(set) var connected = false
    public private(set) var finding = false
    public private(set) var isHost = false
    public private(set) var clockOffset: TimeInterval = 0
    public private(set) var peerName = "Opponent"
    public var localPlayer: Player { isHost ? .coral : .gold }
    @ObservationIgnored var onReady: ((Bool) -> Void)?
    @ObservationIgnored var onState: ((Session) -> Void)?
    @ObservationIgnored var onMove: ((Int, Int, Int) -> Void)?
    @ObservationIgnored var onRequestState: (() -> Void)?
    @ObservationIgnored var onDisconnect: (() -> Void)?
    @ObservationIgnored private var matchID: UUID?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var replica = OnlineReplica()
    @ObservationIgnored private var pingTimes: [UUID: TimeInterval] = [:]
    #if os(iOS)
    var controller: UIViewController?
    @ObservationIgnored private var match: GKMatch?
    @ObservationIgnored private var waitingForAuthentication = false
    @ObservationIgnored private var pendingInvite: GKInvite?
    @ObservationIgnored private var handshakeTask: Task<Void, Never>?
    #endif

    public override init() {
        super.init()
        #if os(iOS)
        if GKLocalPlayer.local.isAuthenticated { GKLocalPlayer.local.register(self) }
        #endif
    }

    public func findMatch() {
        error = nil
        #if os(iOS)
        guard !connected, !finding else { return }
        finding = true
        if GKLocalPlayer.local.isAuthenticated {
            GKLocalPlayer.local.register(self)
            showMatchmaker()
        } else {
            status = "Sign in to Game Center to play online."
            waitingForAuthentication = true
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, authError in
                Task { @MainActor in
                    guard let self else { return }
                    if let viewController { self.controller = viewController; return }
                    self.controller = nil
                    if GKLocalPlayer.local.isAuthenticated {
                        GKLocalPlayer.local.register(self)
                        if self.waitingForAuthentication {
                            Task { @MainActor [weak self] in
                                try? await Task.sleep(for: .milliseconds(400))
                                guard let self else { return }
                                self.finding = true
                                self.showMatchmaker()
                            }
                        }
                    } else {
                        self.finding = false
                        self.error = authError?.localizedDescription ?? "Game Center sign-in was cancelled."
                    }
                    self.waitingForAuthentication = false
                }
            }
        }
        #else
        error = "Online matchmaking is available in the iPhone and iPad app."
        #endif
    }

    func publish(_ session: Session) {
        guard connected, isHost else { return }
        revision += 1
        var packet = OnlinePacket(kind: .state)
        packet.matchID = matchID
        packet.revision = revision
        packet.session = session
        packet.sentAt = Date.now.timeIntervalSince1970
        send(packet)
    }

    func requestMove(column: Int, boardID: Int, expectedMoveCount: Int) {
        guard connected, !isHost else { return }
        var packet = OnlinePacket(kind: .move)
        packet.matchID = matchID
        packet.column = column
        packet.boardID = boardID
        packet.expectedMoveCount = expectedMoveCount
        send(packet)
    }

    public func disconnect(message: String? = nil) {
        if connected {
            var packet = OnlinePacket(kind: .goodbye)
            packet.matchID = matchID
            packet.message = message ?? "The other player ended the match."
            send(packet)
        }
        close(message: message)
    }

    func dismissController() {
        #if os(iOS)
        controller = nil
        #endif
        if !connected {
            finding = false
            #if os(iOS)
            GKMatchmaker.shared().cancel()
            match?.delegate = nil
            match?.disconnect()
            match = nil
            #endif
        }
    }

    private func close(message: String?) {
        #if os(iOS)
        match?.disconnect()
        match?.delegate = nil
        match = nil
        controller = nil
        waitingForAuthentication = false
        handshakeTask?.cancel()
        handshakeTask = nil
        #endif
        connected = false
        finding = false
        pingTimes.removeAll()
        matchID = nil
        revision = 0
        replica = OnlineReplica()
        clockOffset = 0
        status = "Play a friend live with Game Center."
        error = message
        onDisconnect?()
    }

    private func send(_ packet: OnlinePacket) {
        #if os(iOS)
        guard let match else { return }
        do {
            let data = try JSONEncoder().encode(packet)
            guard data.count <= 64 * 1024 else { throw CocoaError(.coderInvalidValue) }
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            close(message: "Connection lost. Please find a new match.")
        }
        #endif
    }

    #if os(iOS)
    private func showMatchmaker() {
        let viewController: GKMatchmakerViewController?
        if let invite = pendingInvite {
            viewController = GKMatchmakerViewController(invite: invite)
            pendingInvite = nil
        } else {
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            request.defaultNumberOfPlayers = 2
            // Match only this protocol version; the host's setup is shared on connect.
            request.playerGroup = 1
            viewController = GKMatchmakerViewController(matchRequest: request)
        }
        guard let viewController else {
            finding = false
            error = "Could not open Game Center matchmaking."
            return
        }
        status = "Invite a friend or find a player."
        viewController.matchmakerDelegate = self
        controller = viewController
    }

    private func attach(_ newMatch: GKMatch) {
        guard !connected, newMatch.expectedPlayerCount == 0, newMatch.players.count == 1 else { return }
        match = newMatch
        newMatch.delegate = self
        let peer = newMatch.players[0]
        guard peer.gamePlayerID != GKLocalPlayer.local.gamePlayerID else {
            close(message: "Two different Game Center accounts are required.")
            return
        }
        peerName = peer.displayName
        isHost = GKLocalPlayer.local.gamePlayerID < peer.gamePlayerID
        matchID = isHost ? UUID() : nil
        revision = 0
        connected = true
        finding = false
        controller = nil
        status = "Connected to \(peerName)"
        onReady?(isHost)
        if !isHost {
            handshakeTask = Task { [weak self] in
                for _ in 0..<15 {
                    guard let self, self.connected, self.matchID == nil else { return }
                    self.send(OnlinePacket(kind: .ready))
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
                self?.close(message: "The game did not connect. Please try again.")
            }
        }
    }

    private func receive(_ data: Data, from player: GKPlayer, on receivedMatch: GKMatch) {
        guard let match, receivedMatch === match, connected,
              match.players.contains(where: { $0.gamePlayerID == player.gamePlayerID }),
              let packet = OnlinePacket.decode(data) else { return }
        switch packet.kind {
        case .ready:
            guard isHost else { return }
            onRequestState?()
        case .state:
            guard !isHost, replica.accept(packet, receivedAt: Date.now.timeIntervalSince1970),
                  let session = replica.session else { return }
            if matchID == nil { clockOffset = replica.initialClockOffset }
            matchID = replica.matchID
            revision = replica.revision
            handshakeTask?.cancel()
            onState?(session)
            ping()
        case .move:
            guard isHost, packet.matchID == matchID,
                  let column = packet.column, (0..<7).contains(column),
                  let board = packet.boardID, (0..<4).contains(board),
                  let count = packet.expectedMoveCount, (0..<42).contains(count) else { return }
            onMove?(column, board, count)
        case .ping:
            guard isHost, packet.matchID == matchID,
                  let pingID = packet.pingID, let time = packet.clientTime, time.isFinite else { return }
            var reply = OnlinePacket(kind: .pong)
            reply.matchID = matchID
            reply.pingID = pingID
            reply.clientTime = time
            reply.sentAt = Date.now.timeIntervalSince1970
            send(reply)
        case .pong:
            guard !isHost, packet.matchID == matchID, let id = packet.pingID,
                  let start = pingTimes.removeValue(forKey: id),
                  let hostTime = packet.sentAt, hostTime.isFinite else { return }
            let end = Date.now.timeIntervalSince1970
            let rtt = end - start
            guard (0...5).contains(rtt) else { return }
            clockOffset = hostTime - (start + end) / 2
        case .goodbye:
            guard packet.matchID == matchID else { return }
            close(message: "The other player ended the match.")
        }
    }

    private func ping() {
        guard !isHost, connected else { return }
        let id = UUID(), now = Date.now.timeIntervalSince1970
        pingTimes = pingTimes.filter { now - $0.value < 10 }
        pingTimes[id] = now
        var packet = OnlinePacket(kind: .ping)
        packet.matchID = matchID
        packet.pingID = id
        packet.clientTime = now
        send(packet)
    }
    #endif
}

#if os(iOS)
extension OnlineClient: GKMatchmakerViewControllerDelegate {
    nonisolated public func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        Task { @MainActor [weak self] in self?.dismissController() }
    }
    nonisolated public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.close(message: error.localizedDescription) }
    }
    nonisolated public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.match = match
            match.delegate = self
            self.attach(match)
        }
    }
}

extension OnlineClient: GKMatchDelegate {
    nonisolated public func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        Task { @MainActor [weak self] in self?.receive(data, from: player, on: match) }
    }
    nonisolated public func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor [weak self] in
            guard let self, self.match === match else { return }
            if state == .disconnected { self.close(message: "Opponent disconnected. Find a new match.") }
            else if state == .connected { self.attach(match) }
        }
    }
    nonisolated public func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.match === match else { return }
            self.close(message: "Game Center connection failed. Please try again.")
        }
    }
}

extension OnlineClient: GKLocalPlayerListener {
    nonisolated public func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.disconnect()
            self.pendingInvite = invite
            self.findMatch()
        }
    }
}

private struct ControllerView: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif

struct OnlinePresentation: ViewModifier {
    let client: OnlineClient
    func body(content: Content) -> some View {
        #if os(iOS)
        content.sheet(isPresented: Binding(get: { client.controller != nil }, set: { if !$0 { client.dismissController() } })) {
            if let controller = client.controller {
                ControllerView(controller: controller).id(ObjectIdentifier(controller)).ignoresSafeArea()
            }
        }
        #else
        content
        #endif
    }
}
