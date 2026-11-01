import SceneKit
import UIKit

/// Timed two-way city traffic lights, with visible red/amber/green lenses.
/// Traffic rules use the same shared signal phase as the emissive graphics.
final class CitySignals {
    private struct Fixture {
        let vertical: Bool
        let red: SCNMaterial
        let amber: SCNMaterial
        let green: SCNMaterial
    }
    private var fixtures: [Fixture] = []
    private var elapsedSinceUpdate = 0.5

    static func isGreen(vertical: Bool, at time: Double) -> Bool {
        let t = time.truncatingRemainder(dividingBy: 24)
        return vertical ? (t < 10) : (t >= 12 && t < 22)
    }

    init(scene: SCNScene) {
        for x in stride(from: -300.0, through: 300.0, by: 150) {
            for z in stride(from: -300.0, through: 300.0, by: 150) {
                makeFixture(scene: scene, x: x + 12.0, z: z - 13.0, vertical: true)
                makeFixture(scene: scene, x: x - 13.0, z: z + 12.0, vertical: false)
            }
        }
        update(time: 0, delta: 0.5)
    }

    func update(time: Double, delta: Double) {
        elapsedSinceUpdate += delta
        guard elapsedSinceUpdate >= 0.30 else { return }
        elapsedSinceUpdate = 0
        let phase = time.truncatingRemainder(dividingBy: 24)
        for signal in fixtures {
            let green = Self.isGreen(vertical: signal.vertical, at: time)
            let amber = signal.vertical ? (phase >= 10 && phase < 12)
                                        : (phase >= 22 && phase < 24)
            signal.green.emission.intensity = green ? 2.6 : 0.08
            signal.amber.emission.intensity = amber ? 2.1 : 0.06
            signal.red.emission.intensity = (!green && !amber) ? 2.4 : 0.07
        }
    }

    private func makeFixture(scene: SCNScene, x: Double, z: Double, vertical: Bool) {
        let poleMaterial = SCNMaterial()
        poleMaterial.diffuse.contents = UIColor(red: 0.19, green: 0.21, blue: 0.24, alpha: 1)
        poleMaterial.metalness.contents = 0.75
        poleMaterial.roughness.contents = 0.43

        let pole = SCNNode(geometry: SCNCylinder(radius: 0.12, height: 5.1))
        pole.geometry?.firstMaterial = poleMaterial
        pole.position = SCNVector3(Float(x), 2.55, Float(z))
        scene.rootNode.addChildNode(pole)

        let housing = SCNNode(geometry: SCNBox(width: 0.55, height: 1.26,
                                                length: 0.38, chamferRadius: 0.09))
        housing.geometry?.firstMaterial = poleMaterial
        housing.position = SCNVector3(Float(x), 5.8, Float(z))
        housing.eulerAngles.y = vertical ? 0 : .pi / 2
        scene.rootNode.addChildNode(housing)

        let colors: [UIColor] = [.red, UIColor(red: 1, green: 0.60, blue: 0.05, alpha: 1), .green]
        var materials: [SCNMaterial] = []
        for (index, color) in colors.enumerated() {
            let mat = SCNMaterial()
            mat.diffuse.contents = color.withAlphaComponent(0.4)
            mat.emission.contents = color
            mat.emission.intensity = 0.06
            let lens = SCNNode(geometry: SCNSphere(radius: 0.16))
            lens.geometry?.firstMaterial = mat
            lens.position = SCNVector3(0, Float(0.37 - Double(index) * 0.36), -0.205)
            housing.addChildNode(lens)
            materials.append(mat)
        }
        fixtures.append(Fixture(vertical: vertical, red: materials[0],
                                amber: materials[1], green: materials[2]))
    }
}
