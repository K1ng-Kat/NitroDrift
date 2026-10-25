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
        view.antialiasingMode = session.graphicsQuality == .balanced ? .multisampling2X : .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // HUD state updates frequently: don't reset the renderer AA mode
        // unless the player actually changed the graphics preset.
        let desired: SCNAntialiasingMode = session.graphicsQuality == .balanced
            ? .multisampling2X : .multisampling4X
        if uiView.antialiasingMode != desired {
            uiView.antialiasingMode = desired
        }
        let useRefraction = session.graphicsQuality == .ultra
            && session.weather == .rain
            && session.screenRefractionEnabled
        if context.coordinator.refractionActive != useRefraction {
            if useRefraction {
                if context.coordinator.refractionTechnique == nil {
                    context.coordinator.refractionTechnique = ScreenSpaceWater.makeTechnique()
                }
                uiView.technique = context.coordinator.refractionTechnique
                context.coordinator.refractionActive = uiView.technique != nil
            } else {
                uiView.technique = nil
                context.coordinator.refractionActive = false
            }
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.technique = nil
        uiView.isPlaying = false
    }

    final class Coordinator: NSObject {
        let session: GameSession
        let world = DrivingWorld()
        private let gamepad = RacingGamepad()
        var refractionTechnique: SCNTechnique?
        var refractionActive = false
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
            gamepad.poll(session)
            world.advance(dt, session: session)
            AudioDirector.shared.update(speed: session.speedKPH, rpm: session.engineRPM, boosting: session.input.nitro,
                                        running: session.phase == .driving && !session.isPaused,
                                        soundEnabled: session.soundEnabled,
                                        musicEnabled: session.musicEnabled)
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}
