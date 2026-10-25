import GameController
import Foundation

/// Polls current controller state once per display frame. Does not overwrite
/// touch controls: controller axes/buttons are stored separately and combined
/// by the vehicle model.
final class RacingGamepad {
    private weak var active: GCController?

    func poll(_ session: GameSession) {
        if active?.extendedGamepad == nil {
            active = GCController.controllers().first(where: { $0.extendedGamepad != nil })
        }
        guard let pad = active?.extendedGamepad else {
            session.input.analogSteering = 0
            session.input.analogThrottle = 0
            session.input.analogBrake = 0
            session.input.gamepadHandbrake = false
            session.input.gamepadNitro = false
            return
        }
        let axis = Double(pad.leftThumbstick.xAxis.value)
        session.input.analogSteering = abs(axis) > 0.10 ? axis : 0
        session.input.analogThrottle = Double(pad.rightTrigger.value)
        session.input.analogBrake = Double(pad.leftTrigger.value)
        session.input.gamepadNitro = pad.buttonA.isPressed
        session.input.gamepadHandbrake = pad.buttonX.isPressed
    }
}
