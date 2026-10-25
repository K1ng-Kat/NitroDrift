import SceneKit
import UIKit

/// Rear-tire spray for driving on wet asphalt. Emitters follow the car, and
/// birth rate tracks road speed. Entire effect is dormant in dry weather.
final class TireSpray {
    private var emitters: [SCNParticleSystem] = []
    private var nodes: [SCNNode] = []

    init() {
        for side: Float in [-1, 1] {
            let emitter = SCNParticleSystem()
            emitter.birthRate = 0
            emitter.particleLifeSpan = 0.39
            emitter.particleLifeSpanVariation = 0.12
            emitter.particleVelocity = 3.8
            emitter.particleVelocityVariation = 2.4
            emitter.particleSize = 0.045
            emitter.particleSizeVariation = 0.035
            emitter.particleColor = UIColor(red: 0.69, green: 0.79, blue: 0.87, alpha: 0.34)
            emitter.blendMode = .alpha
            emitter.spreadingAngle = 20
            emitter.birthLocation = .surface
            emitter.birthDirection = .constant
            emitter.emittingDirection = SCNVector3(0, 0.28, 1)
            emitter.isLightingEnabled = false
            emitter.loops = true
            let tip = SCNNode()
            tip.position = SCNVector3(side * 0.90, 0.24, 1.62)
            tip.addParticleSystem(emitter)
            nodes.append(tip)
            emitters.append(emitter)
        }
    }

    func attach(to car: SCNNode) {
        nodes.forEach { $0.removeFromParentNode(); car.addChildNode($0) }
    }

    func update(wet: Bool, speed: Double, quality: GraphicsQuality) {
        let rate: CGFloat
        if !wet || speed < 4 {
            rate = 0
        } else {
            let limit = quality == .ultra ? 170.0 : quality == .cinematic ? 95.0 : 38.0
            rate = CGFloat(min(limit, (speed - 4) * 3.5))
        }
        emitters.forEach { $0.birthRate = rate }
    }
}
