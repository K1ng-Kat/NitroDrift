#if DEBUG
import Foundation
import Metal
import QuartzCore

/// Enabled only by the simulator capture launch argument. The shell waits for
/// completed Metal work before taking a screenshot and records display cadence.
final class SimulatorCapture {
    private let enabled = ProcessInfo.processInfo.arguments.contains("-ndAutomatedDrive")
    private var intervals: [Double] = []
    private var previous: CFTimeInterval?
    private var didWrite = false
    private var started = false

    func record(_ buffer: MTLCommandBuffer, time: CFTimeInterval, world: DrivingWorld?,
                session: GameSession?) {
        guard enabled, !didWrite, session?.phase == .driving else { return }
        guard let world, !world.hasStreamableRoads || world.residentRoads > 0 else { return }
        if let previous, time > previous { intervals.append((time - previous) * 1000) }
        previous = time
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        if !started {
            started = true
            let output = dir.appendingPathComponent("nd-frame-ready")
            buffer.addCompletedHandler { command in
                if command.status == .completed { try? Data("ready".utf8).write(to: output, options: .atomic) }
            }
        }
        guard intervals.count >= 120, let session else { return }
        didWrite = true
        let sorted = intervals.sorted()
        let report: [String: Any] = [
            "displayIntervalP50ms": sorted[sorted.count/2],
            "displayIntervalP95ms": sorted[sorted.count*95/100],
            "samples": sorted.count, "speedKPH": session.speedKPH,
            "streamingSupported": world.hasStreamableRoads, "residentStreets": world.residentRoads,
            "weather": session.weather.rawValue, "quality": session.graphicsQuality.rawValue,
            "source": "iPhone simulator display link"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) else { return }
        let output = dir.appendingPathComponent("nd-cadence.json")
        buffer.addCompletedHandler { command in
            if command.status == .completed { try? data.write(to: output, options: .atomic) }
        }
    }
}
#endif
