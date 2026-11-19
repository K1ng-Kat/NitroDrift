import SceneKit
import UIKit

/// Shared building meshes, one foreground bridge and instanced street palms.
enum AuthoredCity {
    private static let folder = "Assets.scnassets/City"
    private static let glazing = SCNMaterial()
    private static let silver = SCNMaterial()
    private static var skylineGlazing: [Int: SCNMaterial] = [:]

    private static func image(_ name: String, _ ext: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: folder) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func prepareGlazing() {
        let color = image("facade-day", "jpg"), lit = image("facade-lit", "png")
        for (index, mat) in [glazing, silver].enumerated() {
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = color
            mat.emission.contents = lit
            mat.roughness.contents = index == 0 ? 0.22 : 0.16
            mat.metalness.contents = index == 0 ? 0.38 : 0.61
            for channel in [mat.diffuse, mat.emission] {
                channel.wrapS = .repeat
                channel.wrapT = .repeat
                channel.mipFilter = .linear
                channel.maxAnisotropy = 4
            }
        }
    }

    static func skylineMaterial(for band: Int) -> SCNMaterial {
        if let material = skylineGlazing[band] { return material }
        let base = band.isMultiple(of: 2) ? glazing : silver
        guard let material = base.copy() as? SCNMaterial else { return base }
        let tiling = SCNMatrix4MakeScale(Float(2 + band % 3), Float(4 + band * 2), 1)
        material.diffuse.contentsTransform = tiling
        material.emission.contentsTransform = tiling
        material.multiply.contents = UIColor(white: 0.71 + CGFloat(band) * 0.065, alpha: 1)
        skylineGlazing[band] = material
        return material
    }

    static func setLighting(_ time: StreetTimeOfDay) {
        let intensity: CGFloat = time == .night ? 0.76 : time == .sunset ? 0.16 : 0.015
        for mat in [glazing, silver] + Array(skylineGlazing.values) { mat.emission.intensity = intensity }
    }

    private static func load(_ name: String) -> SCNNode? {
        for ext in ["usdz", "scn", "dae"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: folder),
                  let asset = try? SCNScene(url: url, options: nil), !asset.rootNode.childNodes.isEmpty else { continue }
            asset.rootNode.enumerateChildNodes { node, _ in
                guard let mesh = node.geometry else { return }
                mesh.materials = mesh.materials.map { mat in
                    let role = (mat.name ?? node.name ?? "").lowercased()
                    if role.contains("silverglass") { return silver }
                    if role.contains("glass") { return glazing }
                    mat.lightingModel = .physicallyBased
                    if role.contains("steel") || role.contains("brass") {
                        mat.metalness.contents = 0.73; mat.roughness.contents = 0.34
                    } else if role.contains("water") {
                        mat.roughness.contents = 0.17; mat.metalness.contents = 0.34
                        mat.shaderModifiers = [.surface: """
                        #pragma body
                        float2 p = _surface.diffuseTexcoord * 8.0;
                        float2 r = float2(sin(p.x*3.5 + p.y*0.7 + u_time), cos(p.y*5.1 - u_time*1.4));
                        _surface.normal = normalize(_surface.normal + _surface.tangent * r.x * 0.065 + _surface.bitangent * r.y * 0.04);
                        """]
                    } else if role.contains("lamps") {
                        mat.emission.contents = UIColor(red: 1, green: 0.75, blue: 0.43, alpha: 1)
                    } else {
                        mat.roughness.contents = 0.76
                        if role.contains("foliage") || role.contains("leaflit") { mat.isDoubleSided = true }
                    }
                    return mat
                }
            }
            return asset.rootNode
        }
        return nil
    }

    @discardableResult
    static func install(in scene: SCNScene) -> Bool {
        prepareGlazing()
        if let bridge = load("QuaysideBridge") { scene.rootNode.addChildNode(bridge.clone()) }
        if let palm = load("QuaysidePalm") {
            for (i,z) in [-128,-106,-47,-22,21,53,91,123].enumerated() {
                for side in [-1,1] {
                    let tree = palm.clone()
                    tree.position = SCNVector3(Float(side)*17.1,0,Float(z+side*2))
                    tree.eulerAngles.y = Float(i*5+side)*0.78
                    scene.rootNode.addChildNode(tree)
                }
            }
        }
        let tiles = ["CityBlock","CityBlock0","CityBlock1","CityBlock2"].compactMap(load).filter {
            let b = $0.boundingBox
            return b.min.x >= -62 && b.max.x <= 62 && b.min.z >= -62 && b.max.z <= 62
        }
        guard !tiles.isEmpty else { return false }
        for xi in 0..<6 {
            for zi in 0..<6 {
                let tile = tiles[(xi*7+zi)%tiles.count].clone()
                tile.position = SCNVector3(Float(xi*150-375),0,Float(zi*150-375))
                if (xi+zi).isMultiple(of: 2) { tile.eulerAngles.y = .pi }
                // Set the waterfront blocks back on the west side of the opening straight.
                if xi == 2 && (zi == 2 || zi == 3) {
                    tile.scale = SCNVector3(0.79, zi == 2 ? 0.68 : 0.84, 0.83)
                    tile.eulerAngles.y += .pi/2
                }
                scene.rootNode.addChildNode(tile)
            }
        }
        return true
    }
}
