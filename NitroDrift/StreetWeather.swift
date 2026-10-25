import SceneKit
import UIKit

/// Lightweight local weather emitter and puddle layer. Emitter stays close to
/// the player instead of covering the entire kilometre-wide city.
final class StreetWeather {
    private let rainRoot = SCNNode()
    private let particleSystem = SCNParticleSystem()
    private let puddles: [SCNNode]
    private var isWet = false

    init(scene: SCNScene) {
        let volume = SCNBox(width: 38, height: 1, length: 40, chamferRadius: 0)
        particleSystem.emitterShape = volume
        particleSystem.birthLocation = .volume
        particleSystem.birthDirection = .constant
        particleSystem.emittingDirection = SCNVector3(-0.08, -1, 0.03)
        particleSystem.birthRate = 380
        particleSystem.particleLifeSpan = 0.88
        particleSystem.particleVelocity = 25
        particleSystem.particleVelocityVariation = 6
        particleSystem.particleSize = 0.035
        particleSystem.particleColor = UIColor(red: 0.62, green: 0.77, blue: 0.96, alpha: 0.57)
        particleSystem.blendMode = .alpha
        particleSystem.isLightingEnabled = false
        particleSystem.spreadingAngle = 4
        particleSystem.loops = true
        particleSystem.warmupDuration = 0.5
        rainRoot.addParticleSystem(particleSystem)
        rainRoot.isHidden = true
        scene.rootNode.addChildNode(rainRoot)

        let water = SCNMaterial()
        water.diffuse.contents = UIColor(red: 0.17, green: 0.21, blue: 0.27, alpha: 0.64)
        water.lightingModel = .physicallyBased
        water.roughness.contents = 0.10
        water.metalness.contents = 0.28
        water.isDoubleSided = true
        water.transparencyMode = .dualLayer

        var nodes: [SCNNode] = []
        for i in 0..<48 {
            let road = Float((i % 7 - 3) * 150)
            let offset = Float((i * 67 % 580) - 290)
            let eastWest = i.isMultiple(of: 2)
            let p = SCNNode(geometry: SCNPlane(width: CGFloat(1.5 + Double(i % 5) * 0.9),
                                                height: CGFloat(1.4 + Double(i % 4) * 0.8)))
            p.geometry?.firstMaterial = water
            p.position = eastWest
                ? SCNVector3(offset, 0.10, road + 3.8)
                : SCNVector3(road + 3.8, 0.10, offset)
            p.eulerAngles.x = -.pi / 2
            p.eulerAngles.y = Float((i * 23 % 80)) * .pi / 180
            p.isHidden = true
            p.castsShadow = false
            scene.rootNode.addChildNode(p)
            nodes.append(p)
        }
        puddles = nodes
    }

    func setWet(_ wet: Bool) {
        guard wet != isWet else { return }
        isWet = wet
        rainRoot.isHidden = !wet
        particleSystem.birthRate = wet ? 380 : 0
        for puddle in puddles { puddle.isHidden = !wet }
    }

    func update(x: Double, z: Double) {
        guard isWet else { return }
        rainRoot.position = SCNVector3(Float(x), 23.0, Float(z))
    }
}
