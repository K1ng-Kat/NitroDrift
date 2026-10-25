import AVFoundation
import Foundation

/// Synthesized, royalty-free engine, boost, collision and electronic backing loop.
/// Generated PCM is used instead of shipping copyrighted tracks.
final class AudioDirector {
    static let shared = AudioDirector()
    enum Effect: String { case crash, checkpoint, nitro, police }

    private var engine: AVAudioPlayer?
    private var music: AVAudioPlayer?
    private var effects: [Effect: AVAudioPlayer] = [:]
    private var nitroWasActive = false
    private var initialized = false

    private init() {}

    func update(speed: Int, rpm: Int, boosting: Bool, running: Bool,
                soundEnabled: Bool, musicEnabled: Bool) {
        if !initialized { setup() }
        let shouldPlayEngine = running && soundEnabled
        if shouldPlayEngine {
            engine?.enableRate = true
            engine?.rate = Float(max(0.65, min(2.0, Double(rpm) / 3500.0)))
            engine?.volume = Float(min(0.35, 0.12 + Double(speed) / 1500.0))
            if engine?.isPlaying == false { engine?.play() }
        } else { engine?.pause() }

        if musicEnabled {
            music?.volume = 0.13
            if music?.isPlaying == false { music?.play() }
        } else { music?.pause() }

        if boosting && !nitroWasActive && shouldPlayEngine { play(.nitro) }
        nitroWasActive = boosting
    }

    func play(_ effect: Effect) {
        if !initialized { setup() }
        guard let player = effects[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    private func setup() {
        initialized = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let rate = 22_050
        engine = makePlayer(name: "engine", samples: tones(seconds: 0.50, rate: rate) { t in
            // 90 Hz and its harmonics form a smooth periodic motor timbre.
            let phase = 2 * Double.pi * 90 * t
            return 0.24 * sin(phase) + 0.12 * sin(phase * 2) + 0.08 * sin(phase * 3)
        }, loop: true)
        music = makePlayer(name: "night-drive", samples: tones(seconds: 4, rate: rate) { t in
            let beats = [110.0, 130.81, 164.81, 146.83, 110.0, 130.81, 196.0, 164.81]
            let beat = Int(t * 2) % beats.count
            let f = beats[beat]
            let attack = min(1.0, (t * 2).truncatingRemainder(dividingBy: 1) * 8)
            let decay = exp(-4.0 * (t * 2).truncatingRemainder(dividingBy: 1))
            let bass = sin(2 * .pi * (f / 2) * t) * 0.24
            let arp = sin(2 * .pi * f * t) * 0.13 * attack * decay
            let kickPhase = (t * 2).truncatingRemainder(dividingBy: 1)
            let kick = sin(2 * .pi * (65 - kickPhase * 28) * kickPhase) * exp(-20 * kickPhase) * 0.20
            return bass + arp + kick
        }, loop: true)

        effects[.checkpoint] = makePlayer(name: "checkpoint", samples: tones(seconds: 0.18, rate: rate) { t in
            sin(2 * .pi * (680 + t * 900) * t) * exp(-13 * t) * 0.55
        })
        effects[.crash] = makePlayer(name: "crash", samples: tones(seconds: 0.20, rate: rate) { t in
            (sin(2 * .pi * 82 * t) + sin(2 * .pi * 141 * t)) * exp(-19 * t) * 0.48
        })
        effects[.nitro] = makePlayer(name: "nitro", samples: tones(seconds: 0.35, rate: rate) { t in
            sin(2 * .pi * (180 + 920 * t) * t) * (1 - t) * 0.32
        })
        effects[.police] = makePlayer(name: "police", samples: tones(seconds: 0.6, rate: rate) { t in
            sin(2 * .pi * (t.truncatingRemainder(dividingBy: 0.3) < 0.15 ? 750 : 570) * t) * 0.25
        })
    }

    private func tones(seconds: Double, rate: Int, wave: (Double) -> Double) -> [Int16] {
        let count = Int(seconds * Double(rate))
        return (0..<count).map { n in
            let value = max(-0.9, min(0.9, wave(Double(n) / Double(rate))))
            return Int16(value * 32000)
        }
    }

    private func makePlayer(name: String, samples: [Int16], loop: Bool = false) -> AVAudioPlayer? {
        let sampleRate: UInt32 = 22_050
        var data = Data()
        func appendString(_ value: String) { data.append(contentsOf: value.utf8) }
        func append16(_ value: UInt16) {
            let x = value.littleEndian
            data.append(UInt8(truncatingIfNeeded: x))
            data.append(UInt8(truncatingIfNeeded: x >> 8))
        }
        func append32(_ value: UInt32) {
            let x = value.littleEndian
            for offset in [0, 8, 16, 24] {
                data.append(UInt8(truncatingIfNeeded: x >> offset))
            }
        }
        let byteCount = UInt32(samples.count * 2)
        appendString("RIFF"); append32(byteCount + 36); appendString("WAVE")
        appendString("fmt "); append32(16); append16(1); append16(1)
        append32(sampleRate); append32(sampleRate * 2); append16(2); append16(16)
        appendString("data"); append32(byteCount)
        for sample in samples { append16(UInt16(bitPattern: sample)) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nitro-\(name).wav")
        do {
            try data.write(to: url, options: .atomic)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = loop ? -1 : 0
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
}
