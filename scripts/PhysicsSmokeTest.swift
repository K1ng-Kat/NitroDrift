import Foundation

// Standalone input stub lets us compile and exercise the pure physics core
// without launching SwiftUI/SceneKit or requiring an iOS simulator.
struct DriverInput {
    var left = false, right = false, gas = false, brake = false, nitro = false
    var handbrake = false
    var analogSteering = 0.0, analogThrottle = 0.0, analogBrake = 0.0
    var gamepadHandbrake = false, gamepadNitro = false
}

@main
struct PhysicsSmoke {
    static func main() {
        var car = CarDynamics()
        let dt = 1.0 / 120.0
        var gas = DriverInput()
        gas.gas = true
        for _ in 0..<720 {
            _ = car.step(dt: dt, input: gas, engine: 1, handling: 1,
                         brakes: 0, carTier: 0, assist: true, boosting: false)
        }
        precondition(car.speed > 10 && car.speed < 65,
                     "Acceleration should be gradual, in plausible m/s range")
        precondition(car.rpm >= 875 && car.rpm <= 7050, "RPM outside drivetrain envelope")
        precondition(car.gear >= 1 && car.gear <= 6, "Invalid gear")
        let previousSpeed = car.speed
        var braking = DriverInput()
        braking.brake = true
        for _ in 0..<360 {
            _ = car.step(dt: dt, input: braking, engine: 1, handling: 1,
                         brakes: 2, carTier: 0, assist: true, boosting: false)
        }
        precondition(car.speed < previousSpeed * 0.35, "Braking ineffective")
        precondition(car.x.isFinite && car.z.isFinite && car.heading.isFinite,
                     "Physics must never emit NaN or infinity")

        func corner(_ wet: Bool) -> Double {
            var vehicle = CarDynamics()
            vehicle.speed = 24
            var input = DriverInput()
            input.analogSteering = 0.65
            for _ in 0..<180 {
                _ = vehicle.step(dt: dt, input: input, engine: 0,
                                 handling: 1, brakes: 0, carTier: 0,
                                 assist: false, boosting: false,
                                 surfaceGrip: wet ? 0.73 : 1.0)
            }
            precondition(vehicle.heading.isFinite && vehicle.lateralSpeed.isFinite,
                         "Cornering must remain finite")
            return abs(vehicle.heading)
        }
        let dryYaw = corner(false)
        let wetYaw = corner(true)
        precondition(abs(dryYaw - wetYaw) > 0.02,
                     "Wet surfaces must alter grip and cornering")

        // Regression: the regular brake must never behave like a locked
        // handbrake and throw the car sideways when steering is released.
        for wet in [false, true] {
            var stop = CarDynamics()
            stop.speed = 26.0
            stop.lateralSpeed = 1.5
            stop.yawRate = 0.27
            let originalHeading = stop.heading
            var footBrake = DriverInput()
            footBrake.brake = true
            for frame in 0..<240 {
                let state = stop.step(dt: dt, input: footBrake,
                                      engine: 1, handling: 1, brakes: 0,
                                      carTier: 0, assist: true, boosting: false,
                                      surfaceGrip: wet ? 0.73 : 1.0)
                precondition(state.speed.isFinite && state.slipAngle.isFinite)
                precondition(abs(stop.yawRate) < 1.0,
                             "Regular brake caused runaway yaw at frame \(frame)")
            }
            precondition(stop.speed < 7, "Foot brake did not stop car")
            precondition(abs(stop.heading - originalHeading) < 0.45,
                         "Regular brake swung car sideways")
            precondition(abs(stop.yawRate) < 0.08, "Car still spins while braking")
        }
        // Left/right holding, then releasing and braking should be stable.
        var releaseTest = CarDynamics()
        releaseTest.speed = 20
        var turn = DriverInput()
        turn.left = true
        for _ in 0..<42 {
            _ = releaseTest.step(dt: dt, input: turn,
                                  engine: 0, handling: 0, brakes: 0, carTier: 0,
                                  assist: true, boosting: false)
        }
        var stopStraight = DriverInput()
        stopStraight.brake = true
        for _ in 0..<150 {
            let state = releaseTest.step(dt: dt, input: stopStraight,
                                          engine: 0, handling: 0, brakes: 0, carTier: 0,
                                          assist: true, boosting: false)
            precondition(state.heading.isFinite && abs(releaseTest.yawRate) < 1.0,
                         "Sudden spin after turn-release and brake")
        }

        var handbrake = DriverInput()
        handbrake.analogThrottle = 0.65
        handbrake.analogSteering = -0.4
        handbrake.gamepadHandbrake = true
        for _ in 0..<400 {
            let frame = car.step(dt: dt, input: handbrake, engine: 2,
                                 handling: 1, brakes: 0, carTier: 1,
                                 assist: false, boosting: false,
                                 surfaceGrip: 0.73)
            precondition(frame.speed.isFinite && frame.slipAngle.isFinite,
                         "Analog handbrake physics must be finite")
        }
        print("PASS: acceleration, braking, gears, cornering, wet grip, controller and stability")
    }
}
