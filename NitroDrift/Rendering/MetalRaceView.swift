import MetalKit
import SceneKit

/// Owns drawable sizing and command submission. SceneKit still draws geometry;
/// this is a staged renderer migration, not a replacement geometry engine.
final class MetalRaceView: MTKView, MTKViewDelegate {
    let sceneRenderer: SCNRenderer
    private let commands: MTLCommandQueue
    private var activeQuality: GraphicsQuality?
    private var refraction = false
    private var frameTime: CFTimeInterval = 0

    init?(world: DrivingWorld) {
        guard let gpu = MTLCreateSystemDefaultDevice(),
              let queue = gpu.makeCommandQueue() else { return nil }
        commands = queue
        sceneRenderer = SCNRenderer(device: gpu, options: nil)
        super.init(frame: .zero, device: gpu)
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
        if activeQuality != session.graphicsQuality {
            activeQuality = session.graphicsQuality
            let requested = session.graphicsQuality == .balanced ? 2 : 4
            sampleCount = device?.supportsTextureSampleCount(requested) == true ? requested : 1
            resizeTargets()
        }
        let water = session.graphicsQuality == .ultra && session.weather == .rain
            && session.screenRefractionEnabled
        if water != refraction {
            sceneRenderer.technique = water ? ScreenSpaceWater.makeTechnique() : nil
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
        let scale = min(native, cap / max(bounds.width, bounds.height))
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
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let buffer = commands.makeCommandBuffer() else { return }
        buffer.label = "NitroDrift scene frame"
        sceneRenderer.render(atTime: frameTime,
                             viewport: CGRect(origin: .zero, size: drawableSize),
                             commandBuffer: buffer, passDescriptor: pass)
        buffer.present(drawable)
        buffer.commit()
    }
}
