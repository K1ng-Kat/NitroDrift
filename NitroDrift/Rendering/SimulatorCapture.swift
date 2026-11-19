#if DEBUG
import MetalKit
import QuartzCore

/// Writes launch-test results after frame submission, GPU completion, and a
/// warm-up on the selected course. Disabled for ordinary gameplay.
final class SimulatorCapture {
    private let enabled = ProcessInfo.processInfo.arguments.contains("-ndAutomatedDrive")
    private let demo = ProcessInfo.processInfo.arguments.contains("-ndHandlingDemo")
    private var demoStart: CFTimeInterval?
    private var demoBoosted = false
    private var intervals = [Double]()
    private var previous: CFTimeInterval?
    private var frames = 0
    private var peakSpeed = 0
    private var wroteMarker = false
    private var finished = false

    func record(_ buffer: MTLCommandBuffer, time: CFTimeInterval, view: MTKView,
                world: DrivingWorld?, session: GameSession?) {
        guard enabled, !finished, let session, session.phase == .driving,
              let world, !world.hasStreamableRoads || world.residentRoads > 0,
              let screen = view.window?.windowScene?.screen else { return }
        if demo {
            driveDemo(session, time: time, buffer: buffer)
            return
        }
        // Exercise the same gas input used by the touch pedal in manual mode.
        if !session.easyDrive { session.input.gas = true }
        frames += 1
        peakSpeed = max(peakSpeed,session.speedKPH)
        guard frames > 45 else { return }
        if let previous, time > previous { intervals.append((time-previous)*1000) }
        previous = time
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        if !wroteMarker && peakSpeed >= 5 {
            wroteMarker = true
            write(Data("ready".utf8), to: dir.appendingPathComponent("nd-frame-ready"), after: buffer)
        }
        guard intervals.count >= 120 else { return }
        finished = true
        if !session.easyDrive { session.input.gas = false }
        let sorted = intervals.sorted()
        let report: [String: Any] = [
            "displayIntervalP50ms": sorted[sorted.count/2], "displayIntervalP95ms": sorted[sorted.count*95/100],
            "samples": sorted.count, "speedKPH": session.speedKPH, "peakKPH": peakSpeed,
            "easyDrive": session.easyDrive, "streamingSupported": world.hasStreamableRoads,
            "residentStreets": world.residentRoads, "weather": session.weather.rawValue,
            "quality": session.graphicsQuality.rawValue, "car": session.carStyle.title,
            "wheelPivots": world.activeWheelPivots, "authoredCity": world.authoredBlocksLoaded,
            "viewportWidth": Double(view.bounds.width), "viewportHeight": Double(view.bounds.height),
            "nativeWidth": Double(screen.nativeBounds.width), "nativeHeight": Double(screen.nativeBounds.height),
            "source": "iPhone simulator display link"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) {
            write(data, to: dir.appendingPathComponent("nd-cadence.json"), after: buffer)
        }
    }

    /// A separate recording run uses the live controls without affecting the timing samples.
    private func driveDemo(_ session: GameSession, time: CFTimeInterval, buffer: MTLCommandBuffer) {
        if demoStart == nil {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            session.input.brake = true
            if !wroteMarker {
                wroteMarker = true
                write(Data("ready".utf8), to: dir.appendingPathComponent("nd-demo-ready"), after: buffer)
            }
            guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("nd-demo-start").path) else { return }
            demoStart = time
            session.input.brake = false
        }
        guard let start = demoStart else { return }
        let t = time-start
        // A lane change, a short handbrake correction and one tap of the boost pedal.
        switch t {
        case 2.25..<2.75: session.input.touchSteering = 0.24
        case 2.75..<3.42: session.input.touchSteering = -0.26
        case 3.42..<3.7: session.input.touchSteering = 0.12
        default: session.input.touchSteering = 0
        }
        session.input.handbrake = t >= 2.75 && t < 3.23
        if t >= 4.25 && !demoBoosted {
            demoBoosted = true
            session.pressNitro(true)
            session.pressNitro(false)
        }
    }

    private func write(_ data: Data, to url: URL, after buffer: MTLCommandBuffer) {
        buffer.addCompletedHandler { command in
            if command.status == .completed { try? data.write(to: url, options: .atomic) }
        }
    }
}
#endif
