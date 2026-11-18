import SwiftUI
import UIKit
import SceneKit

/// Hosts the native 3D scene. CADisplayLink runs simulation on the main thread,
/// which also owns the SwiftUI HUD and mutable GameSession state.
struct GameSceneView: UIViewRepresentable {
    @ObservedObject var session: GameSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> UIView {
        if let view = MetalRaceView(world: context.coordinator.world) {
            context.coordinator.metalView = view
            view.configure(session)
            context.coordinator.start()
            return view
        }
        // Keep the app usable if the device cannot initialize Metal resources.
        let fallback = SCNView(frame: .zero)
        fallback.scene = context.coordinator.world.scene
        fallback.pointOfView = context.coordinator.world.pointOfView
        fallback.isPlaying = true
        context.coordinator.start()
        return fallback
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? MetalRaceView)?.configure(session)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
        (uiView as? SCNView)?.isPlaying = false
    }

    final class Coordinator: NSObject {
        let session: GameSession
        let world = DrivingWorld()
        private let gamepad = RacingGamepad()
        weak var metalView: MetalRaceView?
        private var displayLink: CADisplayLink?
        private var previousTimestamp: CFTimeInterval = 0

        init(session: GameSession) {
            self.session = session
        }

        func start() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tick(_ display: CADisplayLink) {
            let dt = previousTimestamp > 0 ? display.timestamp - previousTimestamp : 1.0 / 60.0
            previousTimestamp = display.timestamp
            guard UIApplication.shared.applicationState == .active else {
                previousTimestamp = 0
                session.input.clear()
                return
            }
            gamepad.poll(session)
            world.advance(dt, session: session)
            metalView?.renderFrame(at: display.timestamp)
            AudioDirector.shared.update(speed: session.speedKPH, rpm: session.engineRPM, boosting: session.isBoosting,
                                        running: session.phase == .driving && !session.isPaused,
                                        soundEnabled: session.soundEnabled,
                                        musicEnabled: session.musicEnabled)
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}
