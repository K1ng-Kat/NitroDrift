import Foundation
import SceneKit
import UIKit

/// Optional production-quality USDZ/SCN vehicle import. If no asset exists, the
/// built-in procedural car is retained, so the game always launches offline.
enum VehicleAssetLoader {
    static func installIfAvailable(style: CarStyle,
                                   into parent: SCNNode,
                                   paint: SCNMaterial) -> VehicleArt.Assembly? {
        let name: String
        switch style {
        case .street: name = "StreetGT"
        case .sport: name = "ApexR"
        case .hyper: name = "VortexX"
        }
        let rootFolder = "Assets.scnassets/Vehicles"
        guard let url =
                Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: rootFolder)
                ?? Bundle.main.url(forResource: name, withExtension: "scn", subdirectory: rootFolder),
              let scene = try? SCNScene(url: url, options: nil) else {
            return nil
        }
        let modelRoot = SCNNode()
        modelRoot.name = "imported-vehicle"
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            modelRoot.addChildNode(child)
        }
        // USDZ exports may be Y-up or Z-up and may use X as their length.
        // Normalize the model's scale, height and primary heading to match
        // the simulator convention: front is local -Z, Y is vertical.
        let (bbMin, bbMax) = modelRoot.boundingBox
        let extentX = Double(bbMax.x - bbMin.x)
        let extentY = Double(bbMax.y - bbMin.y)
        let extentZ = Double(bbMax.z - bbMin.z)
        guard extentX.isFinite, extentY.isFinite, extentZ.isFinite,
              extentX > 0.2, extentY > 0.15, extentZ > 0.2 else {
            return nil
        }
        let sourceLength = max(extentX, extentZ)
        let normalizedScale = Float(max(0.20, min(6.0, 4.55 / sourceLength)))
        let offset = SCNNode()
        offset.name = "asset-center"
        offset.scale = SCNVector3(normalizedScale, normalizedScale, normalizedScale)
        offset.position = SCNVector3(
            -(bbMin.x + bbMax.x) * normalizedScale * 0.5,
            -bbMin.y * normalizedScale,
            -(bbMin.z + bbMax.z) * normalizedScale * 0.5
        )
        modelRoot.removeFromParentNode()
        offset.addChildNode(modelRoot)
        let orientation = SCNNode()
        orientation.name = "forward-is-minus-z"
        // Portrait-axis models should not appear sideways on the road.
        if extentX > extentZ * 1.25 {
            orientation.eulerAngles.y = .pi / 2
        }
        orientation.addChildNode(offset)
        modelRoot.enumerateChildNodes { node, _ in
            guard let name = node.name?.lowercased(),
                  name == "paint" || name.hasPrefix("paint_") else { return }
            node.geometry?.materials = [paint]
        }

        // Author wheel pivots with these names in Blender and put geometry
        // beneath a direct child named "roll" to support wheel rotation.
        let names = ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]
        let wheels = names.compactMap { modelRoot.childNode(withName: $0, recursively: true) }
        // If wheels are not properly rigged, render the model but leave wheel
        // steering disabled rather than modifying someone else's mesh.
        parent.addChildNode(orientation)
        return VehicleArt.Assembly(wheels: wheels.count == 4 ? wheels : [], flames: [], brakeLights: [])
    }
}
