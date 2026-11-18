import SceneKit

/// Two draw calls cover the fallback streets. The close road atlases carry
/// these same markings with worn paint and their own roughness.
enum RoadMarkings {
    static func install(in scene: SCNScene, white: SCNMaterial, yellow: SCNMaterial) {
        for center in [false,true] {
            var vertices = [SCNVector3]()
            var indices = [UInt32]()
            func stripe(_ x: Float, _ z: Float, _ w: Float, _ l: Float, _ ew: Bool) {
                let i = UInt32(vertices.count)
                let y: Float = 0.079
                for (a,b) in [(x-w/2,z-l/2),(x-w/2,z+l/2),(x+w/2,z+l/2),(x+w/2,z-l/2)] {
                    vertices.append(ew ? SCNVector3(b,y,-a) : SCNVector3(a,y,b))
                }
                indices.append(contentsOf: [i,i+1,i+2,i,i+2,i+3])
            }
            for across in stride(from: -450, through: 450, by: 150) {
                for mid in stride(from: -375, through: 375, by: 150) {
                    for ew in [false,true] {
                        let a = Float(across), m = Float(mid)
                        if center {
                            for side: Float in [-1,1] { stripe(a+side*0.16,m,0.134,120,ew) }
                        } else {
                            for side: Float in [-1,1] {
                                stripe(a+side*10.9,m,0.14,121,ew)
                                for j in stride(from: 9, through: 120, by: 12) {
                                    stripe(a+side*5.35,m-63+Float(j)+2.25,0.16,4.5,ew)
                                }
                                for j in stride(from: -10, through: 10, by: 2) {
                                    stripe(a+Float(j),m+side*59,0.68,1.66,ew)
                                }
                            }
                        }
                    }
                }
            }
            let normals = Array(repeating: SCNVector3(0,1,0), count: vertices.count)
            let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),SCNGeometrySource(normals: normals)],elements: [element])
            mesh.firstMaterial = center ? yellow : white
            let node = SCNNode(geometry: mesh)
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
        }
    }
}
