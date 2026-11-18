import SceneKit
import UIKit
import simd

enum VehicleAssetLoader {
    private static let folder = "Assets.scnassets/Vehicles"
    private static func assetName(_ style: CarStyle) -> String {
        switch style { case .street: return "StreetGT"; case .sport: return "ApexR"; case .hyper: return "VortexX" }
    }

    private static func artwork(_ style: CarStyle, _ suffix: String, _ ext: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: assetName(style) + "-" + suffix,
                                        withExtension: ext, subdirectory: folder + "/Finishes") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func repaint(_ materials: [SCNMaterial], style: CarStyle, finish: CarPaint) {
        guard !materials.isEmpty, let image = artwork(style, finish.rawValue, "jpg") else { return }
        for material in materials { material.diffuse.contents = image }
    }

    private static func hubCenter(_ wheel: SCNNode, in root: SCNNode) -> SIMD3<Float> {
        let bounds = wheel.boundingBox
        let middle = SCNVector3((bounds.min.x+bounds.max.x)/2, (bounds.min.y+bounds.max.y)/2,
                                (bounds.min.z+bounds.max.z)/2)
        let p = wheel.convertPosition(middle, to: root)
        return SIMD3(p.x, p.y, p.z)
    }

    static func installIfAvailable(style: CarStyle, into parent: SCNNode,
                                   paint: SCNMaterial, finish: CarPaint) -> VehicleArt.Assembly? {
        let name = assetName(style)
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: folder)
                        ?? Bundle.main.url(forResource: name, withExtension: "scn", subdirectory: folder),
              let asset = try? SCNScene(url: url, options: nil) else { return nil }
        let source = SCNNode()
        for child in asset.rootNode.childNodes { source.addChildNode(child) }
        let suffixes = ["wheel_fl","wheel_fr","wheel_rl","wheel_rr"]
        var hubs = [String: SCNNode]()
        var bodies = [SCNMaterial]()
        let rearLampMap = artwork(style, "brakes", "png")
        source.enumerateChildNodes { node, _ in
            let nodeName = node.name?.lowercased() ?? ""
            if let suffix = suffixes.first(where: { nodeName.hasSuffix($0) }), hubs[suffix] == nil {
                hubs[suffix] = node
            }
            guard let geometry = node.geometry else { return }
            geometry.materials = geometry.materials.map { material in
                let n = material.name?.lowercased() ?? ""
                if nodeName == "paint" || nodeName.hasPrefix("paint_") { return paint }
                if nodeName.hasSuffix("_body") || n.contains("body_pbr") {
                    material.lightingModel = .physicallyBased
                    material.clearCoat.contents = 0.89
                    material.clearCoatRoughness.contents = 0.10
                    if let rearLampMap { material.emission.contents = rearLampMap }
                    bodies.append(material)
                } else if nodeName.contains("window") || n.contains("window_glass") {
                    material.lightingModel = .physicallyBased
                    material.diffuse.contents = UIColor(red: 0.075, green: 0.12, blue: 0.17, alpha: 1)
                    material.roughness.contents = 0.11
                    material.metalness.contents = 0.46
                    material.transparency = 1
                }
                return material
            }
        }
        repaint(bodies, style: style, finish: finish)
        let wheels = suffixes.compactMap { hubs[$0] }
        let alignment = SCNNode()
        alignment.addChildNode(source)
        if wheels.count == 4 {
            let p = wheels.map { hubCenter($0, in: source) }
            let across = p[1]+p[3]-p[0]-p[2]
            let lengthwise = p[2]+p[3]-p[0]-p[1]
            guard simd_length(across) > 0.001, simd_length(lengthwise) > 0.001 else { return nil }
            let back = simd_normalize(lengthwise)
            let crossAxle = simd_cross(back, across)
            guard simd_length(crossAxle) > 0.001 else { return nil }
            let up = simd_normalize(crossAxle), right = simd_cross(up, back)
            // Construct the chassis basis from the hubs even when the export
            // includes a presentation rotation. The player faces local -Z.
            alignment.simdTransform = simd_float4x4(columns: (SIMD4(right, 0), SIMD4(up, 0),
                                                                SIMD4(back, 0), SIMD4(0,0,0,1))).inverse
        } else {
            let b = source.boundingBox
            if b.max.x-b.min.x > (b.max.z-b.min.z)*1.25 { alignment.eulerAngles.y = .pi/2 }
        }
        let sized = SCNNode()
        sized.addChildNode(alignment)
        let b = sized.boundingBox
        let length = b.max.z-b.min.z
        guard length.isFinite, length > 0.01 else { return nil }
        let scale = 4.55 / length
        sized.simdScale = SIMD3(repeating: scale)
        sized.simdPosition = SIMD3(-(b.max.x+b.min.x)*scale/2, 0.088-b.min.y*scale,
                                   -(b.max.z+b.min.z)*scale/2)
        let chassis = SCNNode()
        chassis.name = name
        chassis.addChildNode(sized)
        parent.addChildNode(chassis)
        var pivots = [SCNNode]()
        if wheels.count == 4 {
            for wheel in wheels {
                let pivot = SCNNode(), roll = SCNNode()
                pivot.simdPosition = hubCenter(wheel, in: chassis)
                roll.name = "roll"
                chassis.addChildNode(pivot)
                pivot.addChildNode(roll)
                let pose = wheel.simdConvertTransform(matrix_identity_float4x4, to: roll)
                roll.addChildNode(wheel)
                wheel.simdTransform = pose
                pivots.append(pivot)
            }
        }
        let jet = SCNMaterial()
        jet.lightingModel = .constant
        jet.diffuse.contents = UIColor(red: 0.39, green: 0.80, blue: 1, alpha: 0.76)
        jet.emission.contents = UIColor(red: 0.12, green: 0.40, blue: 1, alpha: 1)
        jet.blendMode = .add; jet.writesToDepthBuffer = false
        let nozzle = SCNCone(topRadius: 0, bottomRadius: 0.075, height: 0.53)
        nozzle.radialSegmentCount = 12; nozzle.firstMaterial = jet
        let flames = [-1,1].map { side -> SCNNode in
            let node = SCNNode(geometry: nozzle)
            node.position = SCNVector3(Float(side)*0.58,0.43,2.43)
            node.eulerAngles.x = .pi/2; node.castsShadow = false; node.isHidden = true
            chassis.addChildNode(node)
            return node
        }
        return VehicleArt.Assembly(wheels: pivots, flames: flames, brakeLights: bodies, bodyMaterials: bodies)
    }
}
