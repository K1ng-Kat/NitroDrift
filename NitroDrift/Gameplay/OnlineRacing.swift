import Foundation
import GameKit
import SwiftUI
import UIKit

/// Game Center multiplayer transport: two-player checkpoint racing.
/// Availability requires the Game Center capability and configured leaderboard in App Store Connect.
final class OnlineRacing: NSObject, ObservableObject {
    static let shared = OnlineRacing()
    @Published private(set) var authenticated = false
    @Published private(set) var status = "OFFLINE"
    @Published private(set) var connected = false
    @Published private(set) var remoteState: RemoteCarState?
    @Published private(set) var rivalCheckpoint = 0

    var onMatchReady: (() -> Void)?
    var onMatchEnded: (() -> Void)?

    private var match: GKMatch?
    private var transmitCooldown = 0.0
    private var lastPosition = RemoteCarState(x: 0, z: 35, heading: 0, checkpoint: 0, speed: 0)
    private let leaderboardID = "nitrodrift_wins"

    struct RemoteCarState: Codable {
        let x: Double
        let z: Double
        let heading: Double
        let checkpoint: Int
        let speed: Double
    }

    override private init() {
        super.init()
    }

    func authenticate() {
        guard !authenticated else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let controller {
                    self.presenter()?.present(controller, animated: true)
                    self.status = "SIGN IN TO GAME CENTER"
                } else {
                    self.authenticated = GKLocalPlayer.local.isAuthenticated
                    self.status = self.authenticated ? "GAME CENTER READY" : (error == nil ? "GAME CENTER UNAVAILABLE" : "GAME CENTER SIGN-IN FAILED")
                }
            }
        }
    }

    func findMatch() {
        guard authenticated else { authenticate(); return }
        guard let presenter = presenter() else { return }
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            status = "MATCHMAKING UNAVAILABLE"
            return
        }
        controller.matchmakerDelegate = self
        status = "FINDING OPPONENT"
        presenter.present(controller, animated: true)
    }

    func disconnect() {
        match?.disconnect()
        match = nil
        remoteState = nil
        rivalCheckpoint = 0
        connected = false
        status = authenticated ? "GAME CENTER READY" : "OFFLINE"
    }

    func sendPosition(x: Double, z: Double, heading: Double,
                      speed: Double, checkpoint: Int, dt: Double) {
        guard connected, let match else { return }
        transmitCooldown += dt
        guard transmitCooldown >= 0.1 else { return }
        transmitCooldown = 0
        let packet = RemoteCarState(x: x, z: z, heading: heading,
                                    checkpoint: checkpoint, speed: speed)
        lastPosition = packet
        guard let data = try? JSONEncoder().encode(packet) else { return }
        try? match.sendData(toAllPlayers: data, with: .unreliable)
    }

    func sendFinish(checkpoint: Int) {
        guard connected, let match else { return }
        let packet = RemoteCarState(x: lastPosition.x, z: lastPosition.z,
                                    heading: lastPosition.heading,
                                    checkpoint: checkpoint, speed: 0)
        guard let data = try? JSONEncoder().encode(packet) else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    func submitScore(_ wins: Int) {
        guard authenticated else { return }
        GKLeaderboard.submitScore(wins, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { _ in }
    }

    func showLeaderboards() {
        guard authenticated else { authenticate(); return }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = self
        presenter()?.present(controller, animated: true)
    }

    private func presenter() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        var vc = windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    private func matched(_ newMatch: GKMatch) {
        match = newMatch
        newMatch.delegate = self
        if newMatch.expectedPlayerCount == 0 { ready() }
        else { status = "WAITING FOR PLAYER" }
    }

    private func ready() {
        guard !connected else { return }
        connected = true
        status = "CONNECTED • RACE LIVE"
        rivalCheckpoint = 0
        remoteState = nil
        onMatchReady?()
    }
}

extension OnlineRacing: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
        status = "GAME CENTER READY"
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        status = "MATCHMAKING FAILED"
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        matched(match)
    }
}

extension OnlineRacing: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let packet = try? JSONDecoder().decode(RemoteCarState.self, from: data) else { return }
        DispatchQueue.main.async {
            self.remoteState = packet
            self.rivalCheckpoint = packet.checkpoint
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if match.expectedPlayerCount == 0 { self.ready() }
            case .disconnected:
                self.status = "OPPONENT DISCONNECTED"
                self.connected = false
                self.remoteState = nil
                self.match = nil
                self.onMatchEnded?()
            default: break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async {
            self.status = "MATCH CONNECTION LOST"
            self.disconnect()
            self.onMatchEnded?()
        }
    }
}

extension OnlineRacing: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
