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
    private let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    private var courseReady = false
    private var stillReleased = false
    private var frames = 0
    private var peakSpeed = 0
    private var wroteMarker = false
    private var finished = false

    func record(_ buffer: MTLCommandBuffer, time: CFTimeInterval, view: MTKView,
                world: DrivingWorld?, session: GameSession?) {
        guard enabled, !finished, let session, session.phase == .driving,
              let world, let screen = view.window?.windowScene?.screen else { return }
        if !courseReady {
            guard !world.hasStreamableRoads || world.residentRoads > 0 else {
                world.holdingCaptureFrame = true
                return
            }
            courseReady = true
            world.holdingCaptureFrame = false
        }
        if demo {
            driveDemo(session, world: world, buffer: buffer)
            return
        }
        if !session.easyDrive { session.input.gas = true }
        frames += 1
        peakSpeed = max(peakSpeed, session.speedKPH)
        if !wroteMarker {
            guard frames > 18, session.speedKPH >= 28 else { return }
            wroteMarker = true
            world.holdingCaptureFrame = true
            write(Data("ready".utf8), to: dir.appendingPathComponent("nd-frame-ready"), after: buffer)
            return
        }
        // simctl can take several seconds to acquire an image. Keep the measured approach
        // on screen until the host has the frame, then benchmark a separate stretch of live driving.
        if !stillReleased {
            guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("nd-frame-captured").path) else { return }
            stillReleased = true
            world.holdingCaptureFrame = false
            previous = nil
        }
        if let previous, time > previous { intervals.append((time-previous)*1000) }
        previous = time
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
    private func driveDemo(_ session: GameSession, world: DrivingWorld, buffer: MTLCommandBuffer) {
        if demoStart == nil {
            world.holdingCaptureFrame = true
            if !wroteMarker {
                wroteMarker = true
                write(Data("ready".utf8), to: dir.appendingPathComponent("nd-demo-ready"), after: buffer)
            }
            guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("nd-demo-start").path) else { return }
            demoStart = world.capturedDrivingTime
            world.holdingCaptureFrame = false
        }
        guard let start = demoStart else { return }
        let t = world.capturedDrivingTime - start
        let lane = t < 1.9 ? 0.0 : t < 5.4 ? 2.8 : 0.5
        let heading = atan2(lane - session.playerX, 16) - session.playerHeading
        session.input.touchSteering = min(0.28, max(-0.28, 1.5*atan2(sin(heading),cos(heading))))
        session.input.handbrake = t >= 2.75 && t < 3.15
        if t >= 4.25 && !demoBoosted {
            demoBoosted = true
            session.pressNitro(true)
            session.pressNitro(false)
        }
        if t >= 7.1 {
            world.holdingCaptureFrame = true
            finished = true
            write(Data("done".utf8), to: dir.appendingPathComponent("nd-demo-finished"), after: buffer)
        }
    }

    private func write(_ data: Data, to url: URL, after buffer: MTLCommandBuffer) {
        buffer.addCompletedHandler { command in
            if command.status == .completed { try? data.write(to: url, options: .atomic) }
        }
    }
}
#endif
