import Foundation
import UIKit
import SceneKit

/// Procedural road-grid scene and an approachable arcade driving model.
/// All art is generated in code, so the first build needs no external assets.
final class DrivingWorld {
    let scene = SCNScene()
    private lazy var streets = StreetSystems(scene: scene)

    private let car = SCNNode()
    private let camera = SCNNode()
    private var paintMaterial = SCNMaterial()
    private var nitroFlames: [SCNNode] = []
    private var wheelNodes: [SCNNode] = []
    private let rivalGhost = SCNNode()

    private var dynamics = CarDynamics()
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
    private var displayedStyle: CarStyle = .street

    init() {
        createEnvironment()
        createCar()
        createCamera()
        makeGhost()
        _ = streets
        resetCar()
    }

    func advance(_ dt: TimeInterval, session: GameSession) {
        let delta = min(1.0 / 20.0, max(0.0, dt))
        elapsed += delta

        if lastResetToken != session.resetToken {
            lastResetToken = session.resetToken
            resetCar()
            streets.reset(mode: session.mode, session: session)
        }

        if lastPhase != session.phase {
            lastPhase = session.phase
            session.input.clear()
        }

        if displayedPaint != session.paint {
            displayedPaint = session.paint
            paintMaterial.diffuse.contents = session.paint.color
        }

        if displayedStyle != session.carStyle {
            displayedStyle = session.carStyle
            let tier = Float(session.carStyle.rawValue)
            car.scale = SCNVector3(1 + tier * 0.07, 1 - tier * 0.025, 1 + tier * 0.08)
        }

        if session.phase == .driving && !session.isPaused {
            simulate(delta, session: session)
        } else {
            nitroFlames.forEach { $0.isHidden = true }
        }

        if session.mode == .online && session.phase == .driving && OnlineRacing.shared.connected,
           let rival = OnlineRacing.shared.remoteState {
            rivalGhost.isHidden = false
            rivalGhost.position = SCNVector3(Float(rival.x), 0.05, Float(rival.z))
            rivalGhost.eulerAngles.y = Float(-rival.heading)
        } else {
            rivalGhost.isHidden = true
        }
        updateCamera(delta, session: session)
    }

    private func resetCar() {
        dynamics.reset()
        positionX = dynamics.x
        positionZ = dynamics.z
        heading = dynamics.heading
        velocity = 0
        currentNitro = 100
        driftElapsed = 0
        car.position = SCNVector3(0, 0, 35)
        car.eulerAngles.y = 0
    }

    private func simulate(_ dt: Double, session: GameSession) {
        let input = session.input
        let canNitro = input.nitro && input.gas && currentNitro > 0.4 && velocity > 2
        let meterDrain = max(12, 23 - Double(session.nitroLevel) * 1.8)
        currentNitro = min(100, max(0, currentNitro + (canNitro ? -meterDrain : 6.5) * dt))

        // Integrate at fixed substeps for predictable driving at 30–120 fps.
        let count = max(1, Int(ceil(dt / (1.0 / 90.0))))
        let substep = dt / Double(count)
        var frame = dynamics.step(dt: 0, input: input, engine: session.engineLevel,
                                  handling: session.handlingLevel, brakes: session.brakeLevel,
                                  carTier: session.carStyle.rawValue,
                                  assist: session.handlingAssist, boosting: canNitro)
        let previousX = dynamics.x, previousZ = dynamics.z
        for _ in 0..<count {
            frame = dynamics.step(dt: substep, input: input, engine: session.engineLevel,
                                  handling: session.handlingLevel, brakes: session.brakeLevel,
                                  carTier: session.carStyle.rawValue,
                                  assist: session.handlingAssist, boosting: canNitro)
        }
        let roadX = abs(dynamics.x - (dynamics.x / 150.0).rounded() * 150.0)
        let roadZ = abs(dynamics.z - (dynamics.z / 150.0).rounded() * 150.0)
        let withinMap = abs(dynamics.x) < 497 && abs(dynamics.z) < 497
        if !withinMap || (roadX > 10.9 && roadZ > 10.9) {
            // Soft collision with the curb/building perimeter. Keep heading
            // intact but do not teleport or propel through solid blocks.
            dynamics.x = previousX
            dynamics.z = previousZ
            dynamics.impact(strength: 0.60)
            session.damage = min(100, session.damage + 0.08)
        }

        positionX = dynamics.x
        positionZ = dynamics.z
        heading = dynamics.heading
        velocity = max(0, dynamics.speed)

        let impact = streets.advance(dt, x: positionX, z: positionZ, speed: velocity, session: session)
        if impact > 0 {
            dynamics.impact(strength: impact)
            velocity = dynamics.speed
        }

        car.position = SCNVector3(Float(positionX), Float(0.012 + sin(elapsed * 12) * min(velocity, 24) * 0.00035), Float(positionZ))
        car.eulerAngles = SCNVector3(Float(frame.pitch), Float(-heading), Float(frame.roll))

        for (index, wheel) in wheelNodes.enumerated() {
            // The wheels are physically oriented on the X axis.
            wheel.childNode(withName: "roll", recursively: false)?.eulerAngles.x += Float(velocity * dt / 0.49)
            if index < 2 { wheel.eulerAngles.y = Float(frame.steering * 0.90) }
        }

        for (index, flame) in nitroFlames.enumerated() {
            flame.isHidden = !canNitro
            if canNitro {
                flame.scale = SCNVector3(1, Float(0.85 + 0.17 * sin(elapsed * 27 + Double(index))), 1)
            }
        }

        let slip = abs(frame.slipAngle)
        driftElapsed += dt
        if velocity > 13 && slip > 0.075 && driftElapsed > 0.25 {
            let score = Int(velocity * min(0.4, slip) * 1.8)
            session.addDrift(points: max(2, score))
            driftElapsed = 0
        }

        if session.mode == .online {
            OnlineRacing.shared.sendPosition(x: positionX, z: positionZ, heading: heading,
                                             speed: velocity, checkpoint: session.raceCheckpoint, dt: dt)
        }
        session.updateSprint(delta: dt, meters: velocity * dt)

        hudElapsed += dt
        if hudElapsed >= 0.085 {
            session.playerX = positionX
            session.playerZ = positionZ
            session.playerHeading = heading
            if session.mode == .circuit || session.mode == .online {
                let index = min(session.raceCheckpoint, StreetSystems.checkpoints.count - 1)
                let gate = StreetSystems.checkpoints[index]
                let dx = gate.0 - positionX
                let dz = gate.1 - positionZ
                session.nextGateDistance = Int(hypot(dx, dz))
                let difference = atan2(dx, -dz) - heading
                let relative = atan2(sin(difference), cos(difference))
                session.nextGateDirection = relative > 0.45 ? "↗" : relative < -0.45 ? "↖" : "↑"
            }
            session.speedKPH = Int((velocity * 3.6).rounded())
            session.nitro = currentNitro
            session.gear = max(1, min(6, Int(velocity * 3.6 / 40.0) + 1))
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

        // Narrow enough for readable corners, wider with speed for depth cues.
        let desiredFOV = session.phase == .driving ? 64.0 + min(15.0, velocity * 0.24) : 61.0
        let oldFOV = Double(camera.camera?.fieldOfView ?? 68.0)
        camera.camera?.fieldOfView = CGFloat(oldFOV + (desiredFOV - oldFOV) * min(1, dt * 3.4))

        let lerp = Float(min(1, dt * 5))
        camera.position = SCNVector3(
            camera.position.x + (Float(desiredX) - camera.position.x) * lerp,
            camera.position.y + (Float(desiredY) - camera.position.y) * lerp,
            camera.position.z + (Float(desiredZ) - camera.position.z) * lerp
        )
        camera.look(at: SCNVector3(Float(targetX), Float(targetY), Float(targetZ)))
    }

    private func createEnvironment() {
        scene.background.contents = CityVisuals.sky()
        scene.fogColor = UIColor(red: 0.02, green: 0.03, blue: 0.065, alpha: 1)
        scene.fogStartDistance = 150
        scene.fogEndDistance = 440

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

        let asphalt = CityVisuals.roadMaterial()
        let roadLines = glowMaterial(UIColor(red: 1, green: 0.79, blue: 0.30, alpha: 1), intensity: 0.30)

        for coordinate in stride(from: -450, through: 450, by: 150) {
            addBox(width: 24, height: 0.08, length: 1040,
                   at: SCNVector3(Float(coordinate), 0.025, 0), material: asphalt)
            addBox(width: 1040, height: 0.08, length: 24,
                   at: SCNVector3(0, 0.03, Float(coordinate)), material: asphalt)

            for marker in stride(from: -495, through: 495, by: 15) {
                // Avoid drawing lines directly through road intersections.
                if abs(Double(marker) - (Double(marker) / 150).rounded() * 150) < 17 { continue }
                addBox(width: 0.20, height: 0.012, length: 6.0,
                       at: SCNVector3(Float(coordinate), 0.077, Float(marker)), material: roadLines)
                addBox(width: 6.0, height: 0.012, length: 0.20,
                       at: SCNVector3(Float(marker), 0.078, Float(coordinate)), material: roadLines)
            }
        }

        // Raised sidewalks along blocks, leaving intersections open.
        let concrete = material(UIColor(red: 0.15, green: 0.16, blue: 0.19, alpha: 1), roughness: 0.89)
        let curb = material(UIColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1), roughness: 0.77)
        for road in stride(from: -450, through: 450, by: 150) {
            for segment in stride(from: -375, through: 375, by: 150) {
                for side in [-1.0, 1.0] {
                    let edge = Double(road) + side * 13.25
                    addBox(width: 2.0, height: 0.21, length: 125,
                           at: SCNVector3(Float(edge), 0.065, Float(segment)),
                           material: concrete)
                    addBox(width: 0.19, height: 0.30, length: 125,
                           at: SCNVector3(Float(Double(road) + side * 12.05), 0.09, Float(segment)),
                           material: curb)
                    addBox(width: 125, height: 0.21, length: 2.0,
                           at: SCNVector3(Float(segment), 0.066, Float(edge)),
                           material: concrete)
                    addBox(width: 125, height: 0.30, length: 0.19,
                           at: SCNVector3(Float(segment), 0.09, Float(Double(road) + side * 12.05)),
                           material: curb)
                }
            }
        }

        let crossing = material(UIColor(red: 0.67, green: 0.70, blue: 0.73, alpha: 1), roughness: 0.78)
        for x in [-150, 0, 150] {
            for z in [-150, 0, 150] {
                for stripe in -4...4 {
                    addBox(width: 1.3, height: 0.008, length: 3.2,
                           at: SCNVector3(Float(x) + Float(stripe) * 2.0, 0.085, Float(z) + 17.5),
                           material: crossing)
                    addBox(width: 3.2, height: 0.008, length: 1.3,
                           at: SCNVector3(Float(x) + 17.5, 0.087, Float(z) + Float(stripe) * 2.0),
                           material: crossing)
                }
            }
        }

        var seed: UInt64 = 0xDA71F7
        func random(_ maximum: Int) -> Int {
            seed = 2862933555777941757 &* seed &+ 3037000493
            return Int((seed >> 33) % UInt64(max(1, maximum)))
        }

        for xCell in [-375.0, -225, -75, 75, 225, 375] {
            for zCell in [-375.0, -225, -75, 75, 225, 375] {
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

        addDistrictSign("NITRO", x: -54, y: 31, z: -47, color: .cyan)
        addDistrictSign("MIDTOWN", x: 95, y: 37, z: -190,
                        color: UIColor(red: 0.99, green: 0.28, blue: 0.56, alpha: 1))
        addDistrictSign("RACING", x: -205, y: 48, z: 102,
                        color: UIColor(red: 0.32, green: 0.78, blue: 1, alpha: 1))

        for x in [-450, -300, -150, 0, 150, 300, 450] {
            for z in [-450, -300, -150, 0, 150, 300, 450] {
                addStreetLight(x: Double(x) + 14.5, z: Double(z) + 14.5)
                addStreetLight(x: Double(x) - 14.5, z: Double(z) - 14.5)
            }
        }
    }

    private func addDistrictSign(_ title: String, x: Float, y: Float, z: Float, color: UIColor) {
        let geometry = SCNText(string: title, extrusionDepth: 0.12)
        geometry.font = UIFont.systemFont(ofSize: 7, weight: .black)
        geometry.flatness = 0.30
        geometry.firstMaterial = glowMaterial(color, intensity: 2.0)
        let sign = SCNNode(geometry: geometry)
        sign.position = SCNVector3(x,y,z)
        sign.scale = SCNVector3(0.8,0.8,0.8)
        scene.rootNode.addChildNode(sign)
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
        if abs(x) < 180 && abs(z) < 180 && Int(abs(x + z)).isMultiple(of: 2) {
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
        paintMaterial = VehicleArt.mat(CarPaint.electricBlue.color, metal: 0.60, rough: 0.20)
        let parts = VehicleArt.install(into: car, paint: paintMaterial)
        wheelNodes = parts.wheels
        nitroFlames = parts.flames
    }

    private func makeGhost() {
        let body = SCNBox(width: 2.28, height: 0.72, length: 4.6, chamferRadius: 0.23)
        body.firstMaterial = glowMaterial(UIColor(red: 1, green: 0.42, blue: 0.15, alpha: 0.76), intensity: 0.5)
        let node = SCNNode(geometry: body)
        node.position.y = 1.1
        rivalGhost.addChildNode(node)
        let cabin = SCNNode(geometry: SCNBox(width: 1.65, height: 0.65, length: 1.9, chamferRadius: 0.25))
        cabin.geometry?.firstMaterial = material(.black, roughness: 0.3)
        cabin.position.y = 1.6
        rivalGhost.addChildNode(cabin)
        rivalGhost.isHidden = true
        scene.rootNode.addChildNode(rivalGhost)
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
