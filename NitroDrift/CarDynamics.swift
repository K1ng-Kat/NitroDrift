import Foundation

/// Fixed-step-inspired single-track vehicle model, in SI units.
/// Approximates wheelbase yaw, speed-dependent steering, drag, rolling losses,
/// grip limits, slip recovery, weight transfer, reverse gear and nitrous.
struct CarDynamics {
    var x = 0.0
    var z = 35.0
    var heading = 0.0
    var speed = 0.0                  // Signed longitudinal speed in m/s
    var lateralSpeed = 0.0           // Sideways slip speed
    var yawRate = 0.0
    var steerAngle = 0.0
    var bodyRoll = 0.0
    var bodyPitch = 0.0

    struct Frame {
        let x: Double
        let z: Double
        let heading: Double
        let speed: Double
        let steering: Double
        let slipAngle: Double
        let roll: Double
        let pitch: Double
    }

    mutating func reset() {
        self = CarDynamics()
    }

    mutating func impact(strength: Double) {
        speed *= max(0.15, 1 - strength)
        lateralSpeed *= 0.3
        yawRate *= 0.4
    }

    /// Call on every simulation step at a bounded delta <= 1/30s.
    mutating func step(dt: Double, input: DriverInput,
                       engine: Int, handling: Int, brakes: Int,
                       carTier: Int, assist: Bool, boosting: Bool) -> Frame {
        let dt = min(max(dt, 0), 1.0 / 30.0)
        let throttle = input.gas ? 1.0 : 0.0
        let brake = input.brake ? 1.0 : 0.0
        let steer = Double((input.right ? 1 : 0) - (input.left ? 1 : 0))
        let forwardSpeed = max(0, speed)
        let topSpeed = 48 + Double(engine) * 3.8 + Double(carTier) * 7.0
        let ratio = min(1, forwardSpeed / max(1, topSpeed))
        let engineForce = (9.1 + Double(engine) * 0.84 + Double(carTier) * 0.65) *
            max(0.18, 1 - ratio * ratio * 0.78)
        let nitroForce = boosting ? (7.0 + Double(engine) * 0.4) : 0
        let aerodynamicDrag = 0.0029 * speed * abs(speed)
        let rollingResistance = abs(speed) > 0.12 ? 0.32 * (speed >= 0 ? 1.0 : -1.0) : 0
        let brakeForce = brake * (14 + Double(brakes) * 2.4)
        let engineBrake = throttle == 0 ? min(1.5, abs(speed) * 0.19) * (speed >= 0 ? 1 : -1) : 0
        var acceleration = throttle * (engineForce + nitroForce)
            - brakeForce * (speed >= 0 ? 1 : -1)
            - aerodynamicDrag - rollingResistance - engineBrake

        // Brake is a hold-to-stop control, not an instant full reverse at low speed.
        if brake > 0 && speed <= 0.1 && throttle == 0 { acceleration = 0 }
        speed += acceleration * dt
        if !input.gas && abs(speed) < 0.16 { speed = 0 }
        speed = max(0, min(speed, topSpeed + (boosting ? 15.0 : 0.0)))

        // Less steering lock at speed reduces unrealistic 90-degree turns.
        let normalizedSpeed = min(1, abs(speed) / 48)
        let lock = (0.51 - normalizedSpeed * 0.31) * (1 + Double(handling) * 0.016)
        let targetSteer = steer * lock
        let response = min(1, dt * (8 + Double(handling) * 0.8))
        steerAngle += (targetSteer - steerAngle) * response

        let wheelbase = 2.72
        let theoreticalYaw = speed / wheelbase * tan(steerAngle)
        let availableGrip = (assist ? 0.98 : 0.73) + Double(handling) * 0.058
        let limitedYaw = max(-availableGrip * 9.81 / max(abs(speed), 3.5),
                             min(availableGrip * 9.81 / max(abs(speed), 3.5), theoreticalYaw))
        yawRate += (limitedYaw - yawRate) * min(1, dt * (assist ? 4.0 : 2.6))
        heading += yawRate * dt

        // Slip builds if the requested yaw exceeds tire grip, and recovers
        // progressively rather than snapping the vehicle onto its heading.
        let overLimit = theoreticalYaw - limitedYaw
        let targetSlip = -overLimit * speed * (assist ? 0.32 : 0.63)
        let lateralRecovery = (assist ? 4.5 : 2.5) + Double(handling) * 0.35
        lateralSpeed += (targetSlip - lateralSpeed) * min(1, dt * lateralRecovery)
        lateralSpeed = max(-12, min(12, lateralSpeed))
        let fX = sin(heading), fZ = -cos(heading)
        x += (fX * speed + cos(heading) * lateralSpeed) * dt
        z += (fZ * speed + sin(heading) * lateralSpeed) * dt

        let slipAngle = atan2(lateralSpeed, max(1, speed))
        let targetRoll = max(-0.065, min(0.065, -yawRate * speed * 0.0028))
        let targetPitch = max(-0.045, min(0.045, -acceleration * 0.0027))
        bodyRoll += (targetRoll - bodyRoll) * min(1, dt * 5.5)
        bodyPitch += (targetPitch - bodyPitch) * min(1, dt * 5.5)

        return Frame(x: x, z: z, heading: heading, speed: speed,
                     steering: steerAngle, slipAngle: slipAngle,
                     roll: bodyRoll, pitch: bodyPitch)
    }
}
