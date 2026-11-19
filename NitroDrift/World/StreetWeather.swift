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
    private let waterMasks: [SCNNode]
    private let mirrorMask: SCNNode
    private let water: SCNMaterial
    private var isWet = false
    private var cinematic = false
    private var ultra = false

    private static func applyRipples(to material: SCNMaterial, tiling: Float, strength: CGFloat) {
        let normal = material.normal
        normal.contents = CityVisuals.rainNormalMap()
        normal.intensity = strength
        normal.wrapS = .repeat
        normal.wrapT = .repeat
        let start = SCNMatrix4MakeScale(tiling, tiling, 1)
        var end = start
        end.m41 = 1
        end.m42 = -1
        normal.contentsTransform = start
        let flow = CABasicAnimation(keyPath: "contentsTransform")
        flow.fromValue = NSValue(scnMatrix4: start)
        flow.toValue = NSValue(scnMatrix4: end)
        flow.duration = 5.5
        flow.repeatCount = .infinity
        normal.addAnimation(flow, forKey: "water-flow")
        material.fresnelExponent = 3
    }

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
        rain.particleImage = CityVisuals.droplet
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
        Self.applyRipples(to: film, tiling: 9, strength: 0.11)

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

        // Real geometry mask for the Metal refraction pass. A mask is needed
        // because screen pixels without water must remain completely unchanged.
        let whiteMask = SCNMaterial()
        whiteMask.diffuse.contents = UIColor.white
        whiteMask.lightingModel = .constant
        whiteMask.writesToDepthBuffer = true
        whiteMask.isDoubleSided = true
        let sheet = SCNNode(geometry: SCNPlane(width: 21.2, height: 66))
        sheet.geometry?.firstMaterial = whiteMask
        sheet.position = SCNVector3(0, 0.12, 0)
        sheet.eulerAngles.x = -.pi / 2
        sheet.categoryBitMask = ScreenSpaceWater.waterMaskCategory
        sheet.castsShadow = false
        sheet.isHidden = true
        scene.rootNode.addChildNode(sheet)
        mirrorMask = sheet

        water = SCNMaterial()
        water.diffuse.contents = UIColor(red: 0.11, green: 0.17, blue: 0.24, alpha: 0.62)
        water.lightingModel = .physicallyBased
        water.roughness.contents = 0.05
        water.metalness.contents = 0.0
        water.transparency = 0.67
        water.transparent.contents = CityVisuals.droplet
        water.transparencyMode = .aOne
        water.writesToDepthBuffer = false
        water.isDoubleSided = true
        Self.applyRipples(to: water, tiling: 2, strength: 0.19)

        var nodes: [SCNNode] = []
        var masks: [SCNNode] = []
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

            let mask = SCNNode(geometry: SCNPlane(width: width, height: length))
            mask.geometry?.firstMaterial = whiteMask
            mask.position = SCNVector3(p.position.x, p.position.y + 0.01, p.position.z)
            mask.eulerAngles = p.eulerAngles
            mask.isHidden = true
            mask.castsShadow = false
            mask.categoryBitMask = ScreenSpaceWater.waterMaskCategory
            scene.rootNode.addChildNode(mask)
            masks.append(mask)
        }
        puddles = nodes
        waterMasks = masks
    }

    func configure(wet: Bool, quality: GraphicsQuality, mask: Bool = false) {
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
            waterMasks[index].isHidden = !wet || !ultra || !mask
        }
        mirrorMask.isHidden = !wet || !ultra || !mask
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
            mirrorMask.position = SCNVector3(reflectedRoad.position.x, 0.12, reflectedRoad.position.z)
            mirrorMask.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        } else {
            reflectedRoad.position = SCNVector3(Float(max(-455, min(455, x))), 0.101,
                                                Float(gridZ))
            reflectedRoad.eulerAngles.y = .pi / 2
            mirrorMask.position = SCNVector3(reflectedRoad.position.x, 0.12, reflectedRoad.position.z)
            mirrorMask.eulerAngles = SCNVector3(-Float.pi / 2, 0, Float.pi / 2)
        }
    }
}
