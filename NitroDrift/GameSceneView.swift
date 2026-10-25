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

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.world.scene
        view.pointOfView = context.coordinator.world.pointOfView
        view.backgroundColor = UIColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 1)
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // The coordinator references the observable session directly.
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.isPlaying = false
    }

    final class Coordinator: NSObject {
        let session: GameSession
        let world = DrivingWorld()
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
            world.advance(dt, session: session)
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}
