import Foundation
import SceneKit
import UIKit

/// Recycled skid-mark decals; no unbounded node creation during driving.
final class TireTrails {
    private let pool: [SCNNode]
    private var pointer = 0
    private var travelled = 0.0

    init(scene: SCNScene) {
        let rubber = SCNMaterial()
        rubber.diffuse.contents = UIColor(red: 0.012, green: 0.014, blue: 0.018, alpha: 0.52)
        rubber.lightingModel = .constant
        rubber.writesToDepthBuffer = false
        rubber.isDoubleSided = true
        rubber.transparencyMode = .dualLayer
        pool = (0..<180).map { _ in
            let node = SCNNode(geometry: SCNBox(width: 0.21, height: 0.004,
                                                 length: 0.80, chamferRadius: 0))
            node.geometry?.firstMaterial = rubber
            node.isHidden = true
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
            return node
        }
    }

    func reset() {
        travelled = 0
        // Existing marks stay on the street after a restart, until overwritten.
    }

    func update(dt: Double, x: Double, z: Double, heading: Double,
                speed: Double, slip: Double, yaw: Double) {
        let intensity = abs(slip) + abs(yaw) * 0.13
        guard speed > 9, intensity > 0.085 else {
            travelled = 0
            return
        }
        travelled += speed * dt
        guard travelled > 0.78 else { return }
        travelled = 0
        for wheelX in [-0.86, 0.86] {
            let node = pool[pointer]
            pointer = (pointer + 1) % pool.count
            node.position = SCNVector3(Float(x + cos(heading) * wheelX - sin(heading) * 1.48),
                                       0.093,
                                       Float(z + sin(heading) * wheelX + cos(heading) * 1.48))
            node.eulerAngles.y = Float(-heading)
            node.isHidden = false
            node.opacity = Float(min(0.72, max(0.18, intensity * 1.7)))
        }
    }
}
