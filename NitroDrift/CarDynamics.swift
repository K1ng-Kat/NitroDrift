import Foundation

/// Rear-wheel-drive, single-track vehicle model, metres / seconds / kilograms.
/// This is a real force-based *approximation*, not an authoritative tire simulator.
/// The tire model includes front/rear slip, load transfer, grip saturation and
/// driveline RPM / shifts; the game advances it in small fixed substeps.
struct CarDynamics {
    var x = 0.0
    var z = 35.0
    var heading = 0.0
    var speed = 0.0
    var lateralSpeed = 0.0
    var yawRate = 0.0
    var steerAngle = 0.0
    var bodyRoll = 0.0
    var bodyPitch = 0.0
    var rpm = 900.0
    var gear = 1
    var shiftTime = 0.0

    private let wheelbase = 2.72
    private let frontArm = 1.28
    private let rearArm = 1.44
    private let wheelRadius = 0.335
    private let gravity = 9.81

    struct Frame {
        let x: Double
        let z: Double
        let heading: Double
        let speed: Double
        let steering: Double
        let slipAngle: Double
        let roll: Double
        let pitch: Double
        let rpm: Double
        let gear: Int
        let lateralG: Double
        let gripUsage: Double
    }

    mutating func reset() { self = CarDynamics() }

    mutating func impact(strength: Double) {
        let loss = max(0.08, 1 - min(0.95, max(0, strength)))
        speed *= loss
        lateralSpeed *= loss * 0.65
        yawRate *= loss * 0.65
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        max(minValue, min(maxValue, value))
    }

    mutating func step(dt: Double, input: DriverInput,
                       engine: Int, handling: Int, brakes: Int,
                       carTier: Int, assist: Bool, boosting: Bool,
                       surfaceGrip: Double = 1.0) -> Frame {
        let dt = clamp(dt, 0, 1.0 / 45.0)
        let mass = 1390.0 + Double(carTier) * 95
        let inertia = mass * 1.85
        let cgHeight = 0.53
        let throttle = clamp(max(input.gas ? 1.0 : 0.0, input.analogThrottle), 0, 1)
        let brake = clamp(max(input.brake ? 1.0 : 0.0, input.analogBrake), 0, 1)
        let steeringInput = clamp(Double((input.right ? 1 : 0) - (input.left ? 1 : 0))
                                  + input.analogSteering, -1, 1)
        let handbrake = input.handbrake || input.gamepadHandbrake
        let gears = [3.47, 2.17, 1.56, 1.16, 0.87, 0.70]
        let finalDrive = 3.34
        let gearboxEfficiency = 0.86
        let idleRPM = 875.0
        let redline = 7050.0
        let ratio = gears[max(0, min(5, gear - 1))] * finalDrive
        let wheelsRPM = max(0, speed) / (2 * .pi * wheelRadius) * 60
        let coupledRPM = wheelsRPM * ratio

        shiftTime = max(0, shiftTime - dt)
        if shiftTime <= 0 {
            if coupledRPM > 6600 && gear < 6 {
                gear += 1
                shiftTime = 0.18
            } else if coupledRPM < 1900 && gear > 1 {
                gear -= 1
                shiftTime = 0.13
            }
        }
        let currentRatio = gears[gear - 1] * finalDrive
        // At rest, the automatic transmission acts as if the clutch slips.
        rpm = clamp(max(idleRPM + throttle * 420, wheelsRPM * currentRatio), idleRPM, redline)
        let normalized = clamp(rpm / redline, 0, 1)
        let torqueShape = max(0.42, 1 - pow((normalized - 0.57) / 0.68, 2))
        let peakTorque = 360 + Double(engine) * 34 + Double(carTier) * 70
        let drivenTorque = peakTorque * torqueShape * throttle * (boosting ? 1.32 : 1)
        let wheelForce = shiftTime > 0 ? 0 : drivenTorque * currentRatio * gearboxEfficiency / wheelRadius
        let brakeForce = brake * mass * (10.2 + Double(brakes) * 0.35)
        let aeroDrag = 0.5 * 1.225 * (0.62 + Double(carTier) * 0.035) * speed * abs(speed)
        let rollingResistance = speed > 0.15 ? 0.012 * mass * gravity : 0
        let engineBraking = throttle == 0 ? 300 + 14 * speed : 0

        let desiredLongitudinalForce = wheelForce - brakeForce - aeroDrag
            - rollingResistance - engineBraking
        let mu = ((assist ? 1.04 : 0.91) + Double(handling) * 0.045) * clamp(surfaceGrip, 0.45, 1.2)
        let axleStaticFront = mass * gravity * rearArm / wheelbase
        let axleStaticRear = mass * gravity * frontArm / wheelbase
        let priorLongAcceleration = clamp(desiredLongitudinalForce / mass, -gravity, gravity)
        let transfer = mass * priorLongAcceleration * cgHeight / wheelbase
        let loadF = max(0.20 * mass * gravity, axleStaticFront - transfer)
        let loadR = max(0.20 * mass * gravity, axleStaticRear + transfer)
        // RWD: powered rear axle, braking biased toward the front axle.
        let frontLong = -brakeForce * 0.62
        let rearLong = wheelForce - brakeForce * 0.38 - (handbrake ? mu * loadR * 0.55 : 0)
        let cappedFrontLong = clamp(frontLong, -mu * loadF, mu * loadF)
        let cappedRearLong = clamp(rearLong, -mu * loadR, mu * loadR)
        let longitudinalForce = cappedFrontLong + cappedRearLong - aeroDrag
            - rollingResistance - engineBraking
        let acceleration = longitudinalForce / mass
        speed = max(0, speed + acceleration * dt)
        if !input.gas && speed < 0.20 { speed = 0 }

        // A realistic steering rack has less effective steering angle at
        // high speeds, and cannot snap instantly between full locks.
        let maxSteer = (0.53 - 0.35 * clamp(speed / 62, 0, 1))
            * (1 + Double(handling) * 0.013)
        let desiredSteer = maxSteer * steeringInput
        steerAngle += (desiredSteer - steerAngle) * (1 - exp(-dt * 8.5))

        let corneringStiffnessF = 69000.0 + Double(handling) * 4100
        let corneringStiffnessR = 77000.0 + Double(handling) * 4300
        let forward = max(2.2, speed)
        let slipFront = steerAngle - atan2(lateralSpeed + frontArm * yawRate, forward)
        let slipRear = -atan2(lateralSpeed - rearArm * yawRate, forward)
        // Smoothly saturating slip curves avoid the unrealistic tire-force jump
        // of a hard sign change at the grip limit.
        let lateralBudgetF = sqrt(max(0, pow(mu * loadF, 2) - pow(cappedFrontLong, 2)))
        let lateralBudgetR = sqrt(max(0, pow(mu * loadR, 2) - pow(cappedRearLong, 2))) * (handbrake ? 0.23 : 1.0)
        let frontLateral = lateralBudgetF * tanh(corneringStiffnessF * slipFront / max(1, lateralBudgetF))
        let rearLateral = lateralBudgetR * tanh(corneringStiffnessR * slipRear / max(1, lateralBudgetR))

        let lateralAcceleration = (frontLateral + rearLateral) / mass - speed * yawRate
        let yawAcceleration = (frontArm * frontLateral - rearArm * rearLateral) / inertia
        lateralSpeed = clamp(lateralSpeed + lateralAcceleration * dt, -22, 22)
        yawRate = clamp(yawRate + yawAcceleration * dt, -1.7, 1.7)
        if speed < 2.4 {
            lateralSpeed *= exp(-dt * 7)
            yawRate *= exp(-dt * 4)
        }
        if assist {
            // Optional electronic stability assist: gradually damp extremely
            // large slips while preserving driver input and tire dynamics.
            let sideslip = abs(atan2(lateralSpeed, max(1, speed)))
            if sideslip > 0.26 {
                lateralSpeed *= exp(-dt * 2.4)
                yawRate *= exp(-dt * 0.8)
            }
        }
        heading += yawRate * dt

        let fx = sin(heading), fz = -cos(heading)
        x += (fx * speed + cos(heading) * lateralSpeed) * dt
        z += (fz * speed + sin(heading) * lateralSpeed) * dt

        let slipAngle = atan2(lateralSpeed, max(1, speed))
        let lateralG = clamp((frontLateral + rearLateral) / (mass * gravity), -1.7, 1.7)
        let targetRoll = clamp(-lateralG * 0.075, -0.095, 0.095)
        let targetPitch = clamp(-acceleration / gravity * 0.055, -0.08, 0.08)
        bodyRoll += (targetRoll - bodyRoll) * (1 - exp(-dt * 5.5))
        bodyPitch += (targetPitch - bodyPitch) * (1 - exp(-dt * 4.3))
        let grip = max(abs(frontLateral) / max(1, lateralBudgetF),
                       abs(rearLateral) / max(1, lateralBudgetR))
        return Frame(x: x, z: z, heading: heading, speed: speed,
                     steering: steerAngle, slipAngle: slipAngle,
                     roll: bodyRoll, pitch: bodyPitch, rpm: rpm,
                     gear: gear, lateralG: lateralG, gripUsage: clamp(grip, 0, 1))
    }
}
