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
            let t = Float(i)/6-1, x = t*0.836
            let tip = t*t*t*t
            let z = 2.184-0.050*tip
            positions.append(SCNVector3(x,0.640+0.067*tip,z))
            positions.append(SCNVector3(x,0.846-0.041*tip,z-0.008))
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
            for x: Float in [0.54,0.705] {
                let radius: CGFloat = x < 0.65 ? 0.071 : 0.059
                let z: Float = x < 0.65 ? 2.184 : 2.172
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
        installLouvers(on: chassis)
        return emitter
    }

    private static func installLouvers(on chassis: SCNNode) {
        let windows = chassis.childNodes(passingTest: { node, _ in
            node.name?.lowercased().hasSuffix("_windows") == true && node.geometry != nil
        })
        guard let glass = windows.first else { return }
        func glassPoint(_ x: Float, _ z: Float) -> SCNVector3? {
            let top = glass.convertPosition(SCNVector3(x, 1.8, z), from: chassis)
            let bottom = glass.convertPosition(SCNVector3(x, 0.7, z), from: chassis)
            guard let hit = glass.hitTestWithSegment(from: top, to: bottom,
                                                     options: [SCNHitTestOption.backFaceCulling.rawValue: false]).first else { return nil }
            return chassis.convertPosition(hit.localCoordinates, from: hit.node)
        }

        var vertices = [SCNVector3](), indices = [UInt16]()
        for row in 0..<6 {
            let z = 1.005 + Float(row)*0.078
            let halfWidth = 0.395 + Float(row)*0.009
            let samples = [-halfWidth, 0, halfWidth].compactMap { glassPoint($0, z) }
            guard samples.count == 3 else { continue }
            let base = UInt16(vertices.count)
            for p in samples {
                vertices.append(SCNVector3(p.x, p.y + 0.023, p.z - 0.022))
                vertices.append(SCNVector3(p.x, p.y + 0.013, p.z + 0.037))
            }
            indices += [base,base+1,base+2, base+2,base+1,base+3,
                        base+2,base+3,base+4, base+4,base+3,base+5]
        }
        guard !vertices.isEmpty else { return }
        let geometry = SCNGeometry(sources: [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: vertices.map { _ in SCNVector3(0,0.97,0.24) })
        ], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let graphite = VehicleArt.mat(UIColor(red: 0.065, green: 0.082, blue: 0.11, alpha: 1),
                                     metal: 0.57, rough: 0.27)
        graphite.isDoubleSided = true
        geometry.firstMaterial = graphite
        chassis.addChildNode(SCNNode(geometry: geometry))
    }
}
