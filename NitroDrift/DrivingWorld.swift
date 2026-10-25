import Foundation
import UIKit
import SceneKit

/// Procedural road-grid scene and an approachable arcade driving model.
/// All art is generated in code, so the first build needs no external assets.
final class DrivingWorld {
    let scene = SCNScene()

    private let car = SCNNode()
    private let camera = SCNNode()
    private var paintMaterial = SCNMaterial()
    private var nitroFlames: [SCNNode] = []
    private var wheelNodes: [SCNNode] = []

    private var positionX = 0.0
    private var positionZ = 35.0
    private var heading = 0.0
    private var velocity = 0.0
    private var currentNitro = 100.0
    private var elapsed = 0.0
    private var hudElapsed = 0.0
    private var driftElapsed = 0.0
    private var lastResetToken = -1
    private var lastPhase: GamePhase = .menu
    private var displayedPaint: CarPaint = .electricBlue

    init() {
        createEnvironment()
        createCar()
        createCamera()
        resetCar()
    }

    func advance(_ dt: TimeInterval, session: GameSession) {
        let delta = min(1.0 / 20.0, max(0.0, dt))
        elapsed += delta

        if lastResetToken != session.resetToken {
            lastResetToken = session.resetToken
            resetCar()
        }

        if lastPhase != session.phase {
            lastPhase = session.phase
            session.input.clear()
        }

        if displayedPaint != session.paint {
            displayedPaint = session.paint
            paintMaterial.diffuse.contents = session.paint.color
        }

        if session.phase == .driving && !session.isPaused {
            simulate(delta, session: session)
        } else {
            nitroFlames.forEach { $0.isHidden = true }
        }

        updateCamera(delta, session: session)
    }

    private func resetCar() {
        positionX = 0
        positionZ = 35
        heading = 0
        velocity = 0
        currentNitro = 100
        driftElapsed = 0
        car.position = SCNVector3(0, 0, 35)
        car.eulerAngles.y = 0
    }

    private func simulate(_ dt: Double, session: GameSession) {
        let input = session.input
        let upgrade = Double(session.engineLevel)
        let grip = Double(session.handlingLevel)
        let maxSpeed = 55.0 + upgrade * 5.0 // metres/second
        let canNitro = input.nitro && input.gas && currentNitro > 0.3 && velocity > 3
        let boostedTopSpeed = maxSpeed + (canNitro ? 16.0 : 0.0)

        if input.gas {
            velocity += (13.5 + upgrade * 2.5 + (canNitro ? 23.0 : 0.0)) * dt
        } else {
            velocity -= (2.7 + velocity * 0.035) * dt
        }

        if input.brake {
            velocity -= 31 * dt
        }

        velocity = min(boostedTopSpeed, max(0, velocity))
        if canNitro {
            currentNitro = max(0, currentNitro - dt * 26)
        } else {
            currentNitro = min(100, currentNitro + dt * 5.0)
        }

        let steering = Double((input.right ? 1 : 0) - (input.left ? 1 : 0))
        let speedFactor = min(1, velocity / 13.0)
        let steeringPower = 1.05 + grip * 0.09
        heading += steering * steeringPower * speedFactor * dt

        // A controlled amount of lateral slide rewards high-speed cornering.
        let isDrifting = abs(steering) > 0.1 && velocity > 17
        let slide = isDrifting ? steering * (0.10 - grip * 0.007) * velocity * dt : 0
        let forwardX = sin(heading)
        let forwardZ = -cos(heading)
        let nextX = positionX + forwardX * velocity * dt + cos(heading) * slide
        let nextZ = positionZ + forwardZ * velocity * dt + sin(heading) * slide

        // Roads form a 150 m grid. Streets are 24 m across and off-road blocks
        // are solid; a future milestone will add real vehicle collision meshes.
        let distanceFromNSRoad = abs(nextX - (nextX / 150.0).rounded() * 150.0)
        let distanceFromEWRoad = abs(nextZ - (nextZ / 150.0).rounded() * 150.0)
        let withinMap = abs(nextX) < 355 && abs(nextZ) < 355
        if withinMap && (distanceFromNSRoad < 10.5 || distanceFromEWRoad < 10.5) {
            positionX = nextX
            positionZ = nextZ
        } else {
            velocity *= 0.68
        }

        car.position = SCNVector3(Float(positionX), 0, Float(positionZ))
        car.eulerAngles.y = Float(heading)

        for (index, wheel) in wheelNodes.enumerated() {
            wheel.childNode(withName: "tire", recursively: false)?.eulerAngles.x += Float(velocity * dt / 0.50)
            if index < 2 {
                wheel.eulerAngles.y = Float(steering * 0.28)
            }
        }

        for (index, flame) in nitroFlames.enumerated() {
            flame.isHidden = !canNitro
            if canNitro {
                let size = Float(0.8 + 0.3 * sin(elapsed * 24 + Double(index)))
                flame.scale = SCNVector3(1, size, 1)
            }
        }

        driftElapsed += dt
        if isDrifting && driftElapsed >= 0.16 {
            let points = Int((velocity / 4.0 + grip * 2.0).rounded())
            session.addDrift(points: max(points, 2))
            driftElapsed = 0
        }

        session.updateSprint(delta: dt, meters: velocity * dt)

        hudElapsed += dt
        if hudElapsed >= 0.085 {
            session.speedKPH = Int((velocity * 3.6).rounded())
            session.nitro = currentNitro
            session.gear = max(1, min(6, Int(velocity * 3.6 / 47.0) + 1))
            hudElapsed = 0
        }
    }

    private func updateCamera(_ dt: Double, session: GameSession) {
        var desiredX: Double
        var desiredY: Double
        var desiredZ: Double
        var targetX = positionX
        var targetY = 1.1
        var targetZ = positionZ

        if session.phase == .driving {
            let forwardX = sin(heading)
            let forwardZ = -cos(heading)
            switch session.cameraMode {
            case 1: // hood
                desiredX = positionX + forwardX * 1.15
                desiredY = 1.45
                desiredZ = positionZ + forwardZ * 1.15
                targetX += forwardX * 22
                targetY = 1.45
                targetZ += forwardZ * 22
            case 2: // aerial
                desiredX = positionX - forwardX * 11
                desiredY = 15.0
                desiredZ = positionZ - forwardZ * 11
                targetX += forwardX * 9
                targetZ += forwardZ * 9
            default: // chase
                desiredX = positionX - forwardX * 10.5
                desiredY = 4.7
                desiredZ = positionZ - forwardZ * 10.5
                targetX += forwardX * 7
                targetZ += forwardZ * 7
            }
        } else {
            // Cinematic orbit for the home screen and garage.
            let radius = session.phase == .garage ? 8.0 : 11.0
            let angle = elapsed * 0.12 + 0.6
            desiredX = positionX + sin(angle) * radius
            desiredY = session.phase == .garage ? 3.0 : 4.1
            desiredZ = positionZ + cos(angle) * radius
            targetY = 0.95
        }

        let lerp = Float(min(1, dt * 5))
        camera.position = SCNVector3(
            camera.position.x + (Float(desiredX) - camera.position.x) * lerp,
            camera.position.y + (Float(desiredY) - camera.position.y) * lerp,
            camera.position.z + (Float(desiredZ) - camera.position.z) * lerp
        )
        camera.look(at: SCNVector3(Float(targetX), Float(targetY), Float(targetZ)))
    }

    private func createEnvironment() {
        scene.background.contents = UIColor(red: 0.015, green: 0.024, blue: 0.055, alpha: 1)
        scene.fogColor = UIColor(red: 0.02, green: 0.03, blue: 0.065, alpha: 1)
        scene.fogStartDistance = 105
        scene.fogEndDistance = 390

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 650
        ambient.color = UIColor(red: 0.53, green: 0.65, blue: 1, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let moon = SCNLight()
        moon.type = .directional
        moon.intensity = 1200
        moon.color = UIColor(red: 0.6, green: 0.74, blue: 1, alpha: 1)
        let moonNode = SCNNode()
        moonNode.light = moon
        moonNode.eulerAngles = SCNVector3(-0.95, -0.5, -0.3)
        scene.rootNode.addChildNode(moonNode)

        let ground = SCNFloor()
        ground.reflectivity = 0.09
        ground.firstMaterial = material(UIColor(red: 0.034, green: 0.043, blue: 0.071, alpha: 1), roughness: 0.85)
        let groundNode = SCNNode(geometry: ground)
        groundNode.position.y = -0.08
        scene.rootNode.addChildNode(groundNode)

        let asphalt = material(UIColor(red: 0.062, green: 0.075, blue: 0.10, alpha: 1), roughness: 0.82)
        let roadLines = glowMaterial(UIColor(red: 1, green: 0.79, blue: 0.30, alpha: 1), intensity: 0.30)

        for coordinate in stride(from: -300, through: 300, by: 150) {
            addBox(width: 24, height: 0.08, length: 740,
                   at: SCNVector3(Float(coordinate), 0.025, 0), material: asphalt)
            addBox(width: 740, height: 0.08, length: 24,
                   at: SCNVector3(0, 0.03, Float(coordinate)), material: asphalt)

            for marker in stride(from: -350, through: 350, by: 16) {
                // Avoid drawing lines directly through road intersections.
                if abs(marker % 150) < 17 || abs(marker % 150) > 133 { continue }
                addBox(width: 0.20, height: 0.012, length: 6.0,
                       at: SCNVector3(Float(coordinate), 0.077, Float(marker)), material: roadLines)
                addBox(width: 6.0, height: 0.012, length: 0.20,
                       at: SCNVector3(Float(marker), 0.078, Float(coordinate)), material: roadLines)
            }
        }

        var seed: UInt64 = 0xDA71F7
        func random(_ maximum: Int) -> Int {
            seed = 2862933555777941757 &* seed &+ 3037000493
            return Int((seed >> 33) % UInt64(max(1, maximum)))
        }

        for xCell in [-225.0, -75, 75, 225] {
            for zCell in [-225.0, -75, 75, 225] {
                for offsetX in [-26.0, 26.0] {
                    for offsetZ in [-26.0, 26.0] {
                        let x = xCell + offsetX
                        let z = zCell + offsetZ
                        let width = Double(32 + random(11))
                        let depth = Double(29 + random(12))
                        let height = Double(20 + random(65))
                        let gray = CGFloat(0.055 + Double(random(9)) * 0.01)
                        let facade = material(UIColor(red: gray * 0.82, green: gray, blue: gray * 1.5, alpha: 1), roughness: 0.66)
                        addBox(width: width, height: height, length: depth,
                               at: SCNVector3(Float(x), Float(height / 2), Float(z)), material: facade)

                        let accent = random(2) == 0
                            ? UIColor(red: 0.06, green: 0.66, blue: 1, alpha: 1)
                            : UIColor(red: 0.95, green: 0.24, blue: 0.60, alpha: 1)
                        let strip = glowMaterial(accent, intensity: 1.6)
                        for edgeX in [-width / 2 + 0.65, width / 2 - 0.65] {
                            addBox(width: 0.24, height: height - 1.0, length: 0.25,
                                   at: SCNVector3(Float(x + edgeX), Float(height / 2), Float(z + depth / 2 + 0.03)), material: strip)
                        }
                        let windows = glowMaterial(UIColor(red: 0.65, green: 0.80, blue: 1, alpha: 1), intensity: 0.38)
                        for floor in stride(from: 4.0, to: height - 1.0, by: 8.5) {
                            for column in [-0.27, 0.0, 0.27] {
                                if random(4) == 0 { continue }
                                addBox(width: 2.7, height: 1.45, length: 0.12,
                                       at: SCNVector3(Float(x + width * column), Float(floor), Float(z + depth / 2 + 0.12)),
                                       material: windows)
                            }
                        }
                    }
                }
            }
        }

        for x in [-300, -150, 0, 150, 300] {
            for z in [-300, -150, 0, 150, 300] {
                addStreetLight(x: Double(x) + 14.5, z: Double(z) + 14.5)
                addStreetLight(x: Double(x) - 14.5, z: Double(z) - 14.5)
            }
        }
    }

    private func addStreetLight(x: Double, z: Double) {
        let pole = material(UIColor(red: 0.16, green: 0.2, blue: 0.29, alpha: 1), roughness: 0.5)
        let poleGeometry = SCNCylinder(radius: 0.16, height: 8)
        poleGeometry.firstMaterial = pole
        let poleNode = SCNNode(geometry: poleGeometry)
        poleNode.position = SCNVector3(Float(x), 4, Float(z))
        scene.rootNode.addChildNode(poleNode)

        let lampNode = SCNNode(geometry: SCNSphere(radius: 0.48))
        lampNode.geometry?.firstMaterial = glowMaterial(
            UIColor(red: 0.29, green: 0.73, blue: 1.0, alpha: 1), intensity: 2.6)
        lampNode.position = SCNVector3(Float(x), 8.1, Float(z))
        scene.rootNode.addChildNode(lampNode)

        // Lights on alternating intersections reduce the GPU cost on older iPads.
        if Int(x + z).isMultiple(of: 3) {
            let lamp = SCNLight()
            lamp.type = .omni
            lamp.intensity = 630
            lamp.attenuationStartDistance = 2
            lamp.attenuationEndDistance = 24
            lamp.color = UIColor(red: 0.3, green: 0.68, blue: 1, alpha: 1)
            lampNode.light = lamp
        }
    }

    private func createCar() {
        car.name = "player-car"
        scene.rootNode.addChildNode(car)

        paintMaterial = material(CarPaint.electricBlue.color, roughness: 0.18)
        paintMaterial.metalness.contents = 0.60

        addCarBox(width: 2.25, height: 0.53, length: 4.50,
                  x: 0, y: 0.94, z: 0, material: paintMaterial, chamfer: 0.25)
        let glass = material(UIColor(red: 0.045, green: 0.09, blue: 0.16, alpha: 1), roughness: 0.22)
        addCarBox(width: 1.70, height: 0.65, length: 2.08,
                  x: 0, y: 1.49, z: -0.03, material: glass, chamfer: 0.22)
        addCarBox(width: 2.36, height: 0.19, length: 0.35,
                  x: 0, y: 0.65, z: -2.16, material: paintMaterial, chamfer: 0.05)
        addCarBox(width: 2.35, height: 0.15, length: 0.36,
                  x: 0, y: 0.68, z: 2.13, material: paintMaterial, chamfer: 0.05)

        let black = material(UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1), roughness: 0.9)
        let rim = material(UIColor(red: 0.58, green: 0.64, blue: 0.75, alpha: 1), roughness: 0.28)
        for z in [-1.42, 1.43] {
            for x in [-1.18, 1.18] {
                let steeringPivot = SCNNode()
                steeringPivot.position = SCNVector3(Float(x), 0.49, Float(z))
                let tire = SCNNode(geometry: SCNCylinder(radius: 0.51, height: 0.33))
                tire.name = "tire"
                tire.eulerAngles.z = .pi / 2
                tire.geometry?.firstMaterial = black
                steeringPivot.addChildNode(tire)
                let hub = SCNNode(geometry: SCNCylinder(radius: 0.30, height: 0.34))
                hub.eulerAngles.z = .pi / 2
                hub.geometry?.firstMaterial = rim
                steeringPivot.addChildNode(hub)
                car.addChildNode(steeringPivot)
                wheelNodes.append(steeringPivot)
            }
        }

        let headlight = glowMaterial(.white, intensity: 2.0)
        let tailLight = glowMaterial(UIColor(red: 1, green: 0.06, blue: 0.12, alpha: 1), intensity: 2.0)
        for x in [-0.81, 0.81] {
            addCarBox(width: 0.49, height: 0.15, length: 0.12,
                      x: x, y: 0.97, z: -2.30, material: headlight)
            addCarBox(width: 0.56, height: 0.15, length: 0.12,
                      x: x, y: 0.96, z: 2.30, material: tailLight)

            let flame = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.19, height: 1.25))
            flame.position = SCNVector3(Float(x * 0.68), 0.76, 2.82)
            flame.eulerAngles.x = .pi / 2
            flame.geometry?.firstMaterial = glowMaterial(
                UIColor(red: 0.10, green: 0.78, blue: 1, alpha: 1), intensity: 2.2)
            flame.isHidden = true
            car.addChildNode(flame)
            nitroFlames.append(flame)
        }

        // Small rear spoiler
        addCarBox(width: 2.2, height: 0.10, length: 0.45,
                  x: 0, y: 1.44, z: 1.98, material: black)
    }

    private func createCamera() {
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 70
        camera.camera?.zNear = 0.08
        camera.camera?.zFar = 500
        camera.position = SCNVector3(3.5, 4, 47)
        scene.rootNode.addChildNode(camera)
    }

    var pointOfView: SCNNode { camera }

    private func material(_ color: UIColor, roughness: CGFloat) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.lightingModel = .physicallyBased
        result.isDoubleSided = false
        return result
    }

    private func glowMaterial(_ color: UIColor, intensity: CGFloat) -> SCNMaterial {
        let result = material(color, roughness: 0.3)
        result.emission.contents = color
        result.emission.intensity = intensity
        return result
    }

    private func addBox(width: Double, height: Double, length: Double,
                        at position: SCNVector3, material: SCNMaterial) {
        let geo = SCNBox(width: CGFloat(width), height: CGFloat(height),
                         length: CGFloat(length), chamferRadius: 0)
        geo.firstMaterial = material
        let node = SCNNode(geometry: geo)
        node.position = position
        scene.rootNode.addChildNode(node)
    }

    private func addCarBox(width: Double, height: Double, length: Double,
                           x: Double, y: Double, z: Double,
                           material: SCNMaterial, chamfer: CGFloat = 0) {
        let geo = SCNBox(width: CGFloat(width), height: CGFloat(height),
                         length: CGFloat(length), chamferRadius: chamfer)
        geo.firstMaterial = material
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(Float(x), Float(y), Float(z))
        car.addChildNode(node)
    }
}
