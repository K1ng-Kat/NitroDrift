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
        parent.addChildNode(modelRoot)
        return VehicleArt.Assembly(wheels: wheels.count == 4 ? wheels : [], flames: [])
    }
}
