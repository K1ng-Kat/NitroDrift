import SceneKit
import UIKit

/// Renders wet roads using SceneKit's genuine planar reflection pass, plus
/// Metal surface modifiers for animated ripples, Fresnel and normal distortion.
/// Planar reflections cover ONE local road patch, not the entire kilometre map.
/// The second layer consists of low-cost, softly masked puddle decals.
final class StreetWeather {
    private let rainRoot = SCNNode()
    private let rain = SCNParticleSystem()
    private let reflectedRoad: SCNNode
    private let mirrorFloor: SCNFloor
    private let puddles: [SCNNode]
    private let water: SCNMaterial
    private var isWet = false
    private var cinematic = false
    private var ultra = false

    /// Uses SceneKit surface inputs; applied only to local puddles / road water.
    /// Perturbed normals are evaluated in the correct tangent basis.
    /// Animated light refraction is *approximated* by a varying transparent
    /// water layer. It does not sample the background framebuffer.
    private static let rippleShader = """
    #pragma transparent
    #pragma body
    float2 uv = _surface.diffuseTexcoord;
    float t = u_time;
    float2 q = uv * 9.0;
    float2 moving = q + float2(t * 0.72, -t * 0.53);
    float rippleA = sin(length(moving - float2(3.2, 2.1)) * 11.5 - t * 3.4);
    float rippleB = sin(length(q - float2(7.1, 6.3)) * 14.0 - t * 4.1);
    float waveX = sin(q.x * 3.3 + t * 1.4) * cos(q.y * 2.1 - t * 1.1);
    float waveY = cos(q.y * 4.1 - t * 1.8) * sin(q.x * 2.7 + t * 0.8);
    float2 slope = float2(waveX + rippleA * 0.28, waveY + rippleB * 0.28);
    float3 localNormal = normalize(float3(slope.x * 0.09, slope.y * 0.09, 1.0));
    float3x3 basis = float3x3(_surface.tangent,
                             _surface.bitangent,
                             _surface.geometryNormal);
    _surface.normal = normalize(basis * localNormal);

    float viewCos = clamp(dot(normalize(-_surface.position.xyz),
                              normalize(_surface.normal)), 0.0, 1.0);
    float fresnel = 0.020 + 0.980 * pow(1.0 - viewCos, 5.0);
    float2 edgeUV = (uv - 0.5) * float2(1.0, 1.0);
    float edge = 1.0 - smoothstep(0.32, 0.53, length(edgeUV));
    float sparkle = 0.50 + 0.50 * (waveX * waveY);
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb * float3(0.70, 0.80, 0.89),
                               float3(0.17, 0.33, 0.47),
                               clamp(fresnel * 0.40 + sparkle * 0.045, 0.0, 1.0));
    _surface.diffuse.a *= edge * (0.38 + 0.48 * fresnel);
    """

    /// Ripple normals on the reflection layer (no edge fade: the floor is a
    /// long road patch). Reflection still comes from SCNFloor's render pass.
    private static let filmShader = """
    #pragma transparent
    #pragma body
    float2 uv = _surface.diffuseTexcoord * 20.0;
    float t = u_time;
    float2 wave = float2(
        sin(uv.x * 2.1 + t * 1.0) * cos(uv.y * 2.8 - t * 0.86),
        cos(uv.y * 2.6 + t * 1.24) * sin(uv.x * 2.9 + t * 0.72));
    float3 waterNormal = normalize(float3(wave * 0.035, 1.0));
    float3x3 basis = float3x3(_surface.tangent,
                             _surface.bitangent,
                             _surface.geometryNormal);
    _surface.normal = normalize(basis * waterNormal);
    float facing = clamp(dot(normalize(-_surface.position.xyz),
                             normalize(_surface.normal)), 0.0, 1.0);
    float schlick = 0.020 + 0.980 * pow(1.0 - facing, 5.0);
    _surface.diffuse.a = 0.12 + schlick * 0.28;
    """

    init(scene: SCNScene) {
        let emitter = SCNBox(width: 40, height: 1.0, length: 45, chamferRadius: 0)
        rain.emitterShape = emitter
        rain.birthLocation = .volume
        rain.birthDirection = .constant
        rain.emittingDirection = SCNVector3(-0.11, -1, 0.025)
        rain.birthRate = 440
        rain.particleLifeSpan = 0.91
        rain.particleVelocity = 26
        rain.particleVelocityVariation = 5
        rain.particleSize = 0.025
        rain.particleColor = UIColor(red: 0.71, green: 0.79, blue: 0.99, alpha: 0.48)
        rain.blendMode = .alpha
        rain.isLightingEnabled = false
        rain.spreadingAngle = 3
        rain.loops = true
        rain.warmupDuration = 0.5
        rainRoot.addParticleSystem(rain)
        rainRoot.isHidden = true
        rainRoot.categoryBitMask = 2 // Never render rain into the mirror pass.
        scene.rootNode.addChildNode(rainRoot)

        let film = SCNMaterial()
        film.diffuse.contents = UIColor(red: 0.11, green: 0.16, blue: 0.21, alpha: 0.16)
        film.transparency = 0.33
        film.transparencyMode = .dualLayer
        film.lightingModel = .physicallyBased
        film.roughness.contents = 0.09
        film.metalness.contents = 0.0 // Water is a dielectric.
        film.writesToDepthBuffer = false
        film.isDoubleSided = true
        film.shaderModifiers = [.surface: Self.filmShader]

        let floor = SCNFloor()
        floor.width = 21.2
        floor.length = 66
        floor.reflectivity = 0.55
        floor.reflectionFalloffStart = 1
        floor.reflectionFalloffEnd = 90
        floor.reflectionResolutionScaleFactor = 0.34
        floor.reflectionCategoryBitMask = 1 // Reflect vehicles/buildings, not water decals.
        floor.firstMaterial = film
        let mirrorNode = SCNNode(geometry: floor)
        mirrorNode.position = SCNVector3(0, 0.101, 0)
        mirrorNode.isHidden = true
        mirrorNode.categoryBitMask = 2
        mirrorNode.castsShadow = false
        scene.rootNode.addChildNode(mirrorNode)
        mirrorFloor = floor
        reflectedRoad = mirrorNode

        water = SCNMaterial()
        water.diffuse.contents = UIColor(red: 0.11, green: 0.17, blue: 0.24, alpha: 0.62)
        water.lightingModel = .physicallyBased
        water.roughness.contents = 0.05
        water.metalness.contents = 0.0
        water.transparency = 0.67
        water.transparencyMode = .dualLayer
        water.writesToDepthBuffer = false
        water.isDoubleSided = true
        water.shaderModifiers = [.surface: Self.rippleShader]

        var nodes: [SCNNode] = []
        for i in 0..<72 {
            // Distributed along real road centerlines, not inside buildings.
            let road = Float((i % 7 - 3) * 150)
            let offset = Float((i * 89 % 850) - 425)
            let eastWest = i.isMultiple(of: 2)
            let width = CGFloat(1.5 + Double(i % 5) * 0.82)
            let length = CGFloat(1.8 + Double(i % 4) * 0.86)
            let p = SCNNode(geometry: SCNPlane(width: width, height: length))
            p.geometry?.firstMaterial = water
            p.position = eastWest
                ? SCNVector3(offset, 0.109, road + Float(i % 3) * 2.7)
                : SCNVector3(road + Float(i % 3) * 2.7, 0.109, offset)
            p.eulerAngles.x = -.pi / 2
            p.eulerAngles.z = Float((i * 23 % 75)) * .pi / 180
            p.isHidden = true
            p.categoryBitMask = 2
            p.castsShadow = false
            scene.rootNode.addChildNode(p)
            nodes.append(p)
        }
        puddles = nodes
    }

    func configure(wet: Bool, quality: GraphicsQuality) {
        isWet = wet
        let cinematic = quality != .balanced
        ultra = quality == .ultra
        self.cinematic = cinematic
        rainRoot.isHidden = !wet
        rain.birthRate = wet ? (ultra ? 650 : cinematic ? 440 : 195) : 0
        // Expensive real planar reflection rendering is reserved for high quality.
        reflectedRoad.isHidden = !wet || !cinematic
        mirrorFloor.reflectivity = ultra ? 0.72 : cinematic ? 0.55 : 0
        mirrorFloor.reflectionResolutionScaleFactor = ultra ? 0.55 : cinematic ? 0.34 : 0.17
        for (index, puddle) in puddles.enumerated() {
            puddle.isHidden = !wet || (!cinematic && index.isMultiple(of: 2))
        }
    }

    func update(x: Double, z: Double) {
        guard isWet else { return }
        rainRoot.position = SCNVector3(Float(x), 24.0, Float(z))

        guard cinematic else { return }
        let gridX = (x / 150.0).rounded() * 150.0
        let gridZ = (z / 150.0).rounded() * 150.0
        let dx = abs(x - gridX), dz = abs(z - gridZ)
        // Snap the mirror patch to the nearest road to avoid reflecting below
        // whole buildings. It is deliberately limited to the active street.
        if dx <= dz {
            reflectedRoad.position = SCNVector3(Float(gridX), 0.101,
                                                Float(max(-455, min(455, z))))
            reflectedRoad.eulerAngles.y = 0
        } else {
            reflectedRoad.position = SCNVector3(Float(max(-455, min(455, x))), 0.101,
                                                Float(gridZ))
            reflectedRoad.eulerAngles.y = .pi / 2
        }
    }
}
