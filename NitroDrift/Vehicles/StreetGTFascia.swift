import SceneKit
import UIKit

/// The Street GT's rear assembly is fitted to its normalized 4.55 m wheel rig.
enum StreetGTFascia {
    static func install(on chassis: SCNNode) -> SCNMaterial {
        let carbon = VehicleArt.mat(.darkGray, metal: 0.32, rough: 0.39)
        let folder = "Assets.scnassets/Vehicles/Finishes"
        if let url = Bundle.main.url(forResource: "StreetGT-honeycomb", withExtension: "jpg", subdirectory: folder) {
            carbon.diffuse.contents = UIImage(contentsOfFile: url.path)
        }
        let frame = VehicleArt.mat(UIColor(white: 0.14, alpha: 1), metal: 0.76, rough: 0.29)
        let emitter = VehicleArt.mat(UIColor(red: 0.48, green: 0.014, blue: 0.018, alpha: 1), metal: 0.24, rough: 0.19)
        emitter.emission.contents = UIColor(red: 0.88, green: 0.015, blue: 0.024, alpha: 1)
        let lens = VehicleArt.mat(UIColor(red: 0.34, green: 0.024, blue: 0.038, alpha: 1), metal: 0.32, rough: 0.16)
        var positions = [SCNVector3](), uvs = [CGPoint](), indices = [UInt16]()
        for i in 0...12 {
            let t = Float(i)/6-1, x = t*0.945
            let z = 2.187-max(0,abs(t)-0.72)*0.28
            positions.append(SCNVector3(x,0.643+0.036*t*t,z))
            positions.append(SCNVector3(x,0.848-0.008*t*t,z-0.008))
            uvs += [CGPoint(x: CGFloat(i)/12,y: 1),CGPoint(x: CGFloat(i)/12,y: 0)]
            if i<12 {
                let k=UInt16(i*2)
                indices += [k,k+2,k+1,k+1,k+2,k+3]
            }
        }
        let sources = [SCNGeometrySource(vertices: positions),
                       SCNGeometrySource(normals: positions.map { _ in SCNVector3(0,0,1) }),
                       SCNGeometrySource(textureCoordinates: uvs)]
        let panel = SCNGeometry(sources: sources, elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        panel.firstMaterial = carbon
        chassis.addChildNode(SCNNode(geometry: panel))
        func part(_ geometry: SCNGeometry, _ material: SCNMaterial, _ x: Float, _ y: Float, _ z: Float) -> SCNNode {
            geometry.firstMaterial = material
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x,y,z)
            chassis.addChildNode(node)
            return node
        }
        for side: Float in [-1,1] {
            for x: Float in [0.59,0.80] {
                let radius: CGFloat = x < 0.7 ? 0.073 : 0.065
                let z: Float = x < 0.7 ? 2.193 : 2.178
                let outer = part(SCNTorus(ringRadius: radius+0.009, pipeRadius: 0.009),frame,side*x,0.753,z)
                outer.eulerAngles.x = .pi/2
                let center = part(SCNSphere(radius: radius),lens,side*x,0.753,z+0.004)
                center.scale.z = 0.21
                let ring = part(SCNTorus(ringRadius: radius-0.005, pipeRadius: 0.008),emitter,side*x,0.753,z+0.014)
                ring.eulerAngles.x = .pi/2
            }
            for x: Float in [0.15,0.32] {
                _ = part(SCNBox(width: 0.022,height: 0.09,length: 0.20,chamferRadius: 0.006),frame,side*x,0.34,2.15)
            }
        }
        let plate = VehicleArt.mat(.white, metal: 0.16, rough: 0.36)
        if let url = Bundle.main.url(forResource: "StreetGT-registration", withExtension: "png",subdirectory: folder) {
            plate.diffuse.contents = UIImage(contentsOfFile: url.path)
        }
        _ = part(SCNBox(width: 0.54,height: 0.155,length: 0.026,chamferRadius: 0.012),frame,0,0.567,2.165)
        _ = part(SCNPlane(width: 0.505,height: 0.134),plate,0,0.567,2.18)
        return emitter
    }
}
