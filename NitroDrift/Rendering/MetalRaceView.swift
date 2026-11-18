import MetalKit
import SceneKit

/// Owns drawable sizing and command submission. SceneKit still draws geometry;
/// this is a staged renderer migration, not a replacement geometry engine.
final class MetalRaceView: MTKView, MTKViewDelegate {
    let sceneRenderer: SCNRenderer
    private let commands: MTLCommandQueue
    private weak var raceWorld: DrivingWorld?
    private let inFlight = DispatchSemaphore(value: 2)
    private var renderScale: CGFloat = 1
    private var gpuAverage = 0.0
    private var sampledFrames = 0
    private var activeQuality: GraphicsQuality?
    private var refraction = false
    #if DEBUG
    private let capture = SimulatorCapture()
    private weak var captureWorld: DrivingWorld?
    private weak var captureSession: GameSession?
    #endif
    private var frameTime: CFTimeInterval = 0

    init?(world: DrivingWorld) {
        guard let gpu = MTLCreateSystemDefaultDevice(),
              let queue = gpu.makeCommandQueue() else { return nil }
        commands = queue
        sceneRenderer = SCNRenderer(device: gpu, options: nil)
        super.init(frame: .zero, device: gpu)
        #if DEBUG
        captureWorld = world
        #endif
        raceWorld = world
        sceneRenderer.scene = world.scene
        sceneRenderer.pointOfView = world.pointOfView
        sceneRenderer.autoenablesDefaultLighting = false
        // One main-thread display link owns both simulation and rendering.
        delegate = self
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = false
        colorPixelFormat = .bgra8Unorm_srgb
        depthStencilPixelFormat = .depth32Float_stencil8
        framebufferOnly = true
        isUserInteractionEnabled = false
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(_ session: GameSession) {
        #if DEBUG
        captureSession = session
        #endif
        if activeQuality != session.graphicsQuality {
            activeQuality = session.graphicsQuality
            renderScale = 1; gpuAverage = 0; sampledFrames = 0
            let requested = session.graphicsQuality == .ultra ? 4 : 2
            sampleCount = device?.supportsTextureSampleCount(requested) == true ? requested : 1
            resizeTargets()
        }
        let water = session.graphicsQuality == .ultra && session.weather == .rain
            && session.screenRefractionEnabled
        if water != refraction {
            sceneRenderer.technique = water ? ScreenSpaceWater.makeTechnique() : nil
            raceWorld?.rendersWaterMask = sceneRenderer.technique != nil
            refraction = water
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resizeTargets()
    }

    private func resizeTargets() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let native = window?.screen.scale ?? traitCollection.displayScale
        // Pixel budgets limit memory/bandwidth on iPad while preserving aspect.
        let cap: CGFloat = activeQuality == .ultra ? 2560 : activeQuality == .cinematic ? 1920 : 1440
        let scale = min(native, cap / max(bounds.width, bounds.height)) * renderScale
        let size = CGSize(width: max(1, (bounds.width * scale).rounded()),
                          height: max(1, (bounds.height * scale).rounded()))
        if drawableSize != size { drawableSize = size }
    }

    func renderFrame(at time: CFTimeInterval) {
        guard window != nil, bounds.width > 0, bounds.height > 0 else { return }
        frameTime = time
        draw()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        // Drop a stale submission when two frames are already in flight.
        // Input and simulation continue on the display link.
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let buffer = commands.makeCommandBuffer() else { inFlight.signal(); return }
        let slots = inFlight
        buffer.addCompletedHandler { [weak self] command in
            slots.signal()
            let duration = command.gpuEndTime - command.gpuStartTime
            guard duration > 0, duration < 1 else { return }
            DispatchQueue.main.async { [weak self] in self?.observeGPU(duration) }
        }
        buffer.label = "NitroDrift scene frame"
        sceneRenderer.render(atTime: frameTime,
                             viewport: CGRect(origin: .zero, size: drawableSize),
                             commandBuffer: buffer, passDescriptor: pass)
        #if DEBUG
        capture.record(buffer, time: frameTime, world: captureWorld, session: captureSession)
        #endif
        buffer.present(drawable)
        buffer.commit()
    }
    private func observeGPU(_ seconds: Double) {
        gpuAverage = gpuAverage == 0 ? seconds : gpuAverage * 0.92 + seconds * 0.08
        sampledFrames += 1
        let previous = renderScale
        if sampledFrames >= 30 && gpuAverage > 0.017 {
            renderScale = max(0.72, renderScale - 0.06)
        } else if sampledFrames >= 120 && gpuAverage < 0.011 {
            renderScale = min(1, renderScale + 0.04)
        }
        if renderScale != previous {
            sampledFrames = 0
            resizeTargets()
        }
    }

}
