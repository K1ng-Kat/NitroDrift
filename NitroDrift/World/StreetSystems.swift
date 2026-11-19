import Foundation
import SceneKit
import UIKit

/// Lightweight vehicle AI plus checkpoint-based events. All values are in metres.
/// No network or external art dependencies.
final class StreetSystems {
    struct MovingCar {
        let node: SCNNode
        var x: Double
        var z: Double
        var heading: Double
        var speed: Double
        var cruiseSpeed = 17.0
        let lane: Double
        let horizontal: Bool
        let isPolice: Bool
        var routeIndex: Int = 0
    }

    static let checkpoints: [(Double, Double)] = [
        (0, -150), (150, -150), (300, -150),
        (300, 0), (150, 0), (0, 0),
        (0, 150), (150, 150), (300, 150)
    ]

    private let scene: SCNScene
    private var traffic: [MovingCar] = []
    private var vehicleTemplates: [CarPaint: SCNNode] = [:]
    private var rival: MovingCar?
    private var police: [MovingCar] = []
    private var gates: [SCNNode] = []
    private var lastMode: DriveMode = .freeRide
    private var coolDown = 0.0
    private var tickTime = 0.0
    private var signalTime = 0.0
    private var citySignals: CitySignals

    init(scene: SCNScene) {
        self.scene = scene
        citySignals = CitySignals(scene: scene)
        generateTraffic()
        makeGates()
    }

    func reset(mode: DriveMode, session: GameSession) {
        lastMode = mode
        coolDown = 0
        tickTime = 0
        traffic.forEach { $0.node.isHidden = false }
        if let rival { rival.node.removeFromParentNode() }
        rival = nil
        police.forEach { $0.node.removeFromParentNode() }
        police.removeAll()
        session.raceCheckpointTotal = (mode == .circuit || mode == .online) ? Self.checkpoints.count : 0
        session.raceCheckpoint = 0
        session.racePosition = 1

        if mode == .circuit {
            var bot = MovingCar(node: makeVehicle(finish: .inferno),
                                x: 6, z: 35, heading: 0, speed: 20.5, lane: 0, horizontal: false, isPolice: false)
            bot.node.position = SCNVector3(6, 0, 35)
            bot.routeIndex = 0
            rival = bot
        } else if mode == .pursuit {
            for i in 0..<2 {
                let bot = MovingCar(node: makeVehicle(finish: .midnight, police: true),
                                    x: Double(i * 7 - 4), z: Double(65 + i * 21),
                                    heading: 0, speed: 24, lane: 0, horizontal: false, isPolice: true)
                police.append(bot)
            }
            session.heat = 26
            session.wantedLevel = 2
        }
        gates.forEach { $0.isHidden = mode != .circuit && mode != .online }
        updateGateHighlight(index: 0)
    }

    /// Called by DrivingWorld after the player movement. Returns a bumper impact intensity.
    func advance(_ dt: Double, x: Double, z: Double, speed: Double, session: GameSession) -> Double {
        guard session.phase == .driving && !session.isPaused else { return 0 }
        tickTime += dt
        signalTime += dt
        citySignals.update(time: signalTime, delta: dt)
        coolDown = max(0, coolDown - dt)

        for i in traffic.indices {
            let car = traffic[i]
            let roadPosition = car.horizontal ? car.x : car.z
            let crossing = car.horizontal
                ? ceil(roadPosition / 150.0) * 150.0
                : floor(roadPosition / 150.0) * 150.0
            let distance = car.horizontal
                ? crossing - roadPosition : roadPosition - crossing
            let red = !CitySignals.isGreen(vertical: !car.horizontal, at: signalTime)
            // Slow toward the stop line; a vehicle already inside the
            // intersection may continue clearing it when the light changes.
            let needsStop = red && distance > 5 && distance < 29
            let desiredSpeed = needsStop ? max(0, (distance - 6) * 0.42) : car.cruiseSpeed
            let acceleration = desiredSpeed < car.speed ? -7.5 : 2.2
            traffic[i].speed += acceleration * dt
            if acceleration < 0 { traffic[i].speed = max(desiredSpeed, traffic[i].speed) }
            else { traffic[i].speed = min(desiredSpeed, traffic[i].speed) }
            traffic[i].x += (car.horizontal ? traffic[i].speed * dt : 0)
            traffic[i].z += (car.horizontal ? 0 : -traffic[i].speed * dt)
            if traffic[i].x > 365 { traffic[i].x = -365 }
            if traffic[i].z < -365 { traffic[i].z = 365 }
            traffic[i].node.position = SCNVector3(Float(traffic[i].x), 0, Float(traffic[i].z))
        }

        if session.mode == .circuit || session.mode == .online {
            updateCircuit(dt: dt, x: x, z: z, session: session)
        } else if session.mode == .pursuit {
            updatePolice(dt: dt, x: x, z: z, session: session)
        }

        if tickTime > 0.2 {
            tickTime = 0
            session.district = x >= 140 ? (z < 0 ? "SKYLINE EAST" : "PORT DISTRICT") :
                               x < -140 ? "WEST END" : (z < -140 ? "MIDTOWN" : "DOWNTOWN")
        }

        let allCars = traffic + (rival.map { [$0] } ?? []) + police
        for bot in allCars {
            let distance = max(abs(bot.x-x), abs(bot.z-z))
            let nearby = distance < 58
            let outside = distance > 230
            if bot.node.isHidden != outside { bot.node.isHidden = outside }
            guard !outside else { continue }
            if let body = bot.node.childNode(withName: "close-body", recursively: false), body.isHidden == nearby {
                body.isHidden = !nearby
                bot.node.childNode(withName: "axles", recursively: false)?.isHidden = !nearby
                bot.node.childNode(withName: "distant-body", recursively: false)?.isHidden = nearby
                bot.node.childNode(withName: "ground-contact", recursively: false)?.isHidden = !nearby
            }
            if nearby {
                let turn = Float(bot.speed * dt / 0.35)
                for wheel in bot.node.childNode(withName: "axles", recursively: false)?.childNodes ?? [] {
                    wheel.eulerAngles.x -= turn
                }
            }
        }
        guard coolDown <= 0 else { return 0 }
        for bot in allCars {
            let distance = hypot(bot.x - x, bot.z - z)
            if distance < 3.1 {
                coolDown = 1.0
                session.damage = min(100, session.damage + min(25, abs(speed - bot.speed) * 0.3 + 8))
                session.feedback(.heavy)
                if session.soundEnabled { AudioDirector.shared.play(.crash) }
                if session.mode == .pursuit && bot.isPolice {
                    session.heat = min(100, session.heat + 23)
                }
                return 0.39
            }
        }
        return 0
    }

    private func updateCircuit(dt: Double, x: Double, z: Double, session: GameSession) {
        let checkpoints = Self.checkpoints
        let index = session.raceCheckpoint
        if index < checkpoints.count {
            let point = checkpoints[index]
            // Requires physically passing gates in order, not raw distance driven.
            if hypot(x - point.0, z - point.1) < 20 {
                session.raceCheckpoint += 1
                session.earn(75, reputation: 5)
                session.feedback(.light)
                if session.soundEnabled { AudioDirector.shared.play(.checkpoint) }
                updateGateHighlight(index: session.raceCheckpoint)
            }
        }

        if var bot = rival {
            let targetIndex = min(bot.routeIndex, checkpoints.count - 1)
            let target = checkpoints[targetIndex]
            let dx = target.0 - bot.x
            let dz = target.1 - bot.z
            let distance = hypot(dx, dz)
            if distance < 8 {
                bot.routeIndex += 1
            } else {
                let move = min(distance, bot.speed * dt)
                bot.x += dx / distance * move
                bot.z += dz / distance * move
                bot.heading = atan2(dx, -dz)
            }
            bot.node.position = SCNVector3(Float(bot.x), 0, Float(bot.z))
            bot.node.eulerAngles.y = Float(-bot.heading)
            rival = bot
            session.racePosition = bot.routeIndex > session.raceCheckpoint ? 2 : 1

            if bot.routeIndex >= checkpoints.count && session.raceCheckpoint < checkpoints.count {
                session.completeEvent(won: false, distance: session.raceCheckpoint,
                                      title: "RIVAL WINS", reward: 160)
            }
        }

        if session.mode == .online && OnlineRacing.shared.rivalCheckpoint >= checkpoints.count && session.raceCheckpoint < checkpoints.count {
            session.completeEvent(won: false, distance: session.raceCheckpoint, title: "RIVAL WINS", reward: 160)
        }

        if session.raceCheckpoint >= checkpoints.count && session.raceResult == nil {
            session.completeEvent(won: true, distance: checkpoints.count,
                                  title: "CIRCUIT VICTORY", reward: 1800)
        }
    }

    private func updatePolice(dt: Double, x: Double, z: Double, session: GameSession) {
        var closest = Double.greatestFiniteMagnitude
        for index in police.indices {
            let dx = x - police[index].x
            let dz = z - police[index].z
            let dist = hypot(dx, dz)
            closest = min(closest, dist)
            if dist > 0.2 {
                // Police choose the nearest cardinal grid corridor as the player moves.
                let desiredHeading = atan2(dx, -dz)
                var turn = desiredHeading - police[index].heading
                while turn > .pi { turn -= 2 * .pi }
                while turn < -.pi { turn += 2 * .pi }
                police[index].heading += max(-dt * 1.9, min(dt * 1.9, turn))
                police[index].x += sin(police[index].heading) * police[index].speed * dt
                police[index].z -= cos(police[index].heading) * police[index].speed * dt
                police[index].node.position = SCNVector3(Float(police[index].x), 0, Float(police[index].z))
                police[index].node.eulerAngles.y = Float(-police[index].heading)
            }
        }
        session.policeNearby = closest < 32
        if closest < 12 {
            session.heat = min(100, session.heat + dt * 5)
        } else if closest > 35 {
            session.heat = max(0, session.heat - dt * 2.4)
        }
        session.wantedLevel = min(5, max(0, Int(ceil(session.heat / 20))))
        if session.heat >= 100 && session.raceResult == nil {
            session.completeEvent(won: false, distance: 0, title: "BUSTED", reward: 0)
        }
    }

    private func generateTraffic() {
        for index in 0..<14 {
            let horizontal = index.isMultiple(of: 2)
            let coordinate = Double((index % 5 - 2) * 150) + (index.isMultiple(of: 3) ? 4.5 : -4.5)
            let crossing = Double((index * 53 % 620) - 310)
            let finishes: [CarPaint] = [.midnight, .pearl, .violet, .inferno]
            let node = makeVehicle(finish: finishes[index % finishes.count])
            let bot = MovingCar(node: node,
                                x: horizontal ? crossing : coordinate,
                                z: horizontal ? coordinate : crossing,
                                heading: horizontal ? .pi / 2 : 0,
                                speed: Double(11 + index % 8),
                                lane: coordinate,
                                horizontal: horizontal,
                                isPolice: false)
            node.position = SCNVector3(Float(bot.x), 0, Float(bot.z))
            node.eulerAngles.y = Float(-bot.heading)
            var driving = bot
            driving.cruiseSpeed = bot.speed
            traffic.append(driving)
        }
    }

    private func makeGates() {
        for point in Self.checkpoints {
            let root = SCNNode()
            root.position = SCNVector3(Float(point.0), 0, Float(point.1))
            for x in [-6.0, 6.0] {
                let post = SCNNode(geometry: SCNBox(width: 0.5, height: 7,
                                                     length: 0.5, chamferRadius: 0.1))
                post.position = SCNVector3(Float(x), 3.5, 0)
                post.geometry?.firstMaterial = glowing(.cyan)
                root.addChildNode(post)
            }
            let banner = SCNNode(geometry: SCNBox(width: 12.6, height: 0.45,
                                                   length: 0.5, chamferRadius: 0))
            banner.position.y = 7
            banner.geometry?.firstMaterial = glowing(.cyan)
            root.addChildNode(banner)
            root.isHidden = true
            scene.rootNode.addChildNode(root)
            gates.append(root)
        }
    }

    private func updateGateHighlight(index: Int) {
        for (i, gate) in gates.enumerated() {
            gate.isHidden = (lastMode != .circuit && lastMode != .online) || i != index
        }
    }

    private func glowing(_ color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = 1.75
        return mat
    }

    private func vehicleTemplate(finish: CarPaint) -> SCNNode {
        if let template = vehicleTemplates[finish] { return template }
        let style: CarStyle = (finish == .violet || finish == .pearl) ? .hyper : .sport
        let model = SCNNode()
        let paint = VehicleArt.mat(finish.color, metal: 0.55, rough: 0.24)
        let assembly = VehicleAssetLoader.installIfAvailable(style: style, into: model,
                                                           paint: paint, finish: finish)
                       ?? VehicleArt.install(into: model, paint: paint)
        for jet in assembly.flames { jet.removeFromParentNode() }
        let axles = SCNNode()
        axles.name = "axles"
        for wheel in assembly.wheels {
            let pose = wheel.convertTransform(SCNMatrix4Identity, to: model)
            wheel.removeFromParentNode()
            let rolling = wheel.flattenedClone()
            rolling.transform = pose
            axles.addChildNode(rolling)
        }
        let template = SCNNode()
        let detailed = model.flattenedClone()
        detailed.name = "close-body"
        template.addChildNode(detailed)
        let silhouette = SculptedCarShell.make(paint: paint)
        let cabin = SCNBox(width: 1.55, height: 0.39, length: 1.75, chamferRadius: 0.18)
        cabin.firstMaterial = VehicleArt.mat(UIColor(white: 0.095, alpha: 1), metal: 0.34, rough: 0.16)
        let roof = SCNNode(geometry: cabin)
        roof.position.y = 1.27
        silhouette.addChildNode(roof)
        let distant = silhouette.flattenedClone()
        distant.name = "distant-body"
        distant.isHidden = true
        template.addChildNode(distant)
        template.addChildNode(axles)
        template.addChildNode(CityVisuals.vehicleShadow())
        vehicleTemplates[finish] = template
        return template
    }

    private func makeVehicle(finish: CarPaint, police: Bool = false) -> SCNNode {
        let root = vehicleTemplate(finish: finish).clone()
        if police {
            let roofHeight = root.boundingBox.max.y
            for x: Float in [-0.29, 0.29] {
                let beacon = SCNNode(geometry: SCNBox(width: 0.50, height: 0.18,
                                                        length: 0.35, chamferRadius: 0.06))
                beacon.geometry?.firstMaterial = glowing(x < 0 ? .red : .blue)
                beacon.position = SCNVector3(x, roofHeight + 0.05, 0)
                root.addChildNode(beacon)
            }
        }
        scene.rootNode.addChildNode(root)
        return root
    }

}
