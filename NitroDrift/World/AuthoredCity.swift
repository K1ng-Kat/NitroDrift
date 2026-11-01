import Foundation
import SceneKit
import UIKit

/// Optional hand-authored environment tiles, kept separate from driving logic.
/// Tile meshes are visual-only: the existing 150m street grid still owns physics,
/// collision limits, checkpoints, traffic navigation and the minimap.
enum AuthoredCity {
    private static let folder = "Assets.scnassets/City"

    /// Every tile is 150 x 150 metres and centered on one city block.
    /// The installer deliberately does not remove roads, curbs or gameplay nodes.
    /// A missing or malformed asset simply leaves the procedural city visible.
    @discardableResult
    static func install(in scene: SCNScene) -> Bool {
        guard let url = Bundle.main.url(forResource: "CityBlock", withExtension: "usdz", subdirectory: folder)
                ?? Bundle.main.url(forResource: "CityBlock", withExtension: "scn", subdirectory: folder),
              let source = try? SCNScene(url: url, options: nil),
              !source.rootNode.childNodes.isEmpty else { return false }

        let root = SCNNode()
        root.name = "authored-city-tiles"
        // An authored CityBlock asset uses metres, Y-up, and origin at block center.
        // Road surfaces should be omitted so the existing road's wet/dry
        // material and traffic handling are preserved.
        for x in [-375.0, -225.0, -75.0, 75.0, 225.0, 375.0] {
            for z in [-375.0, -225.0, -75.0, 75.0, 225.0, 375.0] {
                let tile = SCNNode()
                tile.name = "block-\(Int(x))-\(Int(z))"
                for child in source.rootNode.childNodes {
                    tile.addChildNode(child.clone())
                }
                tile.position = SCNVector3(Float(x), 0, Float(z))
                root.addChildNode(tile)
            }
        }
        scene.rootNode.addChildNode(root)
        return true
    }
}
