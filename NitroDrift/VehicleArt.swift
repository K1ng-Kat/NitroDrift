import SceneKit
import UIKit

/// Stylized but dimensionally plausible sports coupe made from beveled panels,
/// sloped glass, lights, wheels, vents and interior details; no external assets.
enum VehicleArt {
    struct Assembly {
        let wheels: [SCNNode]
        let flames: [SCNNode]
    }

    static func install(into car: SCNNode, paint: SCNMaterial) -> Assembly {
        let black = mat(UIColor(red: 0.018, green: 0.021, blue: 0.030, alpha: 1), metal: 0.20, rough: 0.69)
        let carbon = mat(UIColor(red: 0.055, green: 0.065, blue: 0.085, alpha: 1), metal: 0.6, rough: 0.25)
        let glass = mat(UIColor(red: 0.05, green: 0.12, blue: 0.19, alpha: 1), metal: 0.22, rough: 0.14)
        let steel = mat(UIColor(red: 0.43, green: 0.49, blue: 0.57, alpha: 1), metal: 0.85, rough: 0.25)
        let headlamp = emissive(UIColor(red: 0.80, green: 0.94, blue: 1, alpha: 1), strength: 1.4)
        let tailLamp = emissive(UIColor(red: 1, green: 0.06, blue: 0.09, alpha: 1), strength: 1.5)
        let orange = emissive(UIColor(red: 1.0, green: 0.28, blue: 0.04, alpha: 1), strength: 1.3)

        func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, at x: Float, _ y: Float, _ z: Float,
                 material: SCNMaterial, bevel: CGFloat = 0.02, parent: SCNNode? = nil) -> SCNNode {
            let g = SCNBox(width: w, height: h, length: l, chamferRadius: bevel)
            g.firstMaterial = material
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(x,y,z)
            (parent ?? car).addChildNode(n)
            return n
        }

        // Chassis and coupe body; forward is local negative Z.
        box(2.10, 0.15, 4.75, at: 0, 0.49, 0, material: black, bevel: 0.10)
        box(2.18, 0.53, 4.44, at: 0, 0.82, -0.02, material: paint, bevel: 0.22)
        box(1.98, 0.17, 1.66, at: 0, 1.13, -1.31, material: paint, bevel: 0.08)
        box(2.12, 0.19, 1.05, at: 0, 1.11, 1.62, material: paint, bevel: 0.07)
        box(1.91, 0.11, 2.07, at: 0, 1.73, 0.08, material: carbon, bevel: 0.07)

        // Side and windshield areas: genuinely angled polygons instead of a
        // rectangular aquarium-like roof.
        let cabinVerts: [SCNVector3] = [
            SCNVector3(-0.97,1.16,-1.21), SCNVector3(0.97,1.16,-1.21),
            SCNVector3(-0.82,1.74,-0.64), SCNVector3(0.82,1.74,-0.64),
            SCNVector3(-0.85,1.74,0.83), SCNVector3(0.85,1.74,0.83),
            SCNVector3(-0.99,1.16,1.36), SCNVector3(0.99,1.16,1.36)
        ]
        let cabinFaces: [Int32] = [
            0,1,3, 0,3,2, // front screen
            2,3,5, 2,5,4, // roof
            4,5,7, 4,7,6, // rear glass
            0,2,4, 0,4,6, // left glass
            1,7,5, 1,5,3  // right glass
        ]
        let shell = SCNNode(geometry: polygons(cabinVerts, indices: cabinFaces, material: glass))
        car.addChildNode(shell)

        // A-pillars, roof line and two door seams.
        for side: Float in [-1,1] {
            let x = side * 0.90
            box(0.085, 0.07, 1.63, at: side * 0.85, 1.73, 0.08, material: black)
            box(0.08, 0.64, 0.08, at: x, 1.42, -0.64, material: black)
            box(0.045, 0.60, 0.10, at: x, 1.42, 0.84, material: black)
            box(0.08, 0.12, 0.35, at: side * 1.12, 1.18, -0.55, material: black, bevel: 0.03)
            box(0.045, 0.07, 0.28, at: side * 1.11, 1.10, 0.40, material: steel)
            // Side skirt, air intake, wheel arch trim.
            box(0.13, 0.14, 2.30, at: side * 1.09, 0.57, 0.01, material: carbon)
            box(0.04, 0.17, 0.54, at: side * 1.117, 0.80, 1.26, material: black)
        }

        // Low black grille/air intakes, diffuser and split headlight housings.
        box(1.22, 0.19, 0.06, at: 0, 0.66, -2.29, material: black)
        for side: Float in [-1,1] {
            box(0.48, 0.18, 0.07, at: side * 0.82, 0.67, -2.30, material: black)
            box(0.61, 0.08, 0.07, at: side * 0.76, 1.06, -2.30, material: headlamp)
            box(0.49, 0.11, 0.06, at: side * 0.80, 0.97, 2.25, material: tailLamp)
            box(0.58, 0.06, 0.07, at: side * 0.78, 0.88, 2.27, material: black)
        }
        box(1.92, 0.07, 0.09, at: 0, 0.98, 2.28, material: tailLamp)
        box(1.65, 0.10, 0.23, at: 0, 0.54, -2.31, material: carbon)
        box(1.65, 0.11, 0.24, at: 0, 0.53, 2.30, material: carbon)

        // Slim trunk wing and two supports.
        for side: Float in [-1,1] {
            box(0.12, 0.40, 0.11, at: side * 0.75, 1.30, 1.81, material: black)
        }
        box(2.32, 0.10, 0.46, at: 0, 1.53, 1.86, material: carbon, bevel: 0.04)

        var wheels: [SCNNode] = []
        for z: Float in [-1.47,1.51] {
            for side: Float in [-1,1] {
                let pivot = SCNNode()
                pivot.position = SCNVector3(side * 1.14, 0.49, z)
                let rolling = SCNNode()
                rolling.name = "roll"
                pivot.addChildNode(rolling)
                let tire = SCNNode(geometry: SCNCylinder(radius: 0.49, height: 0.33))
                tire.name = "tire"
                tire.eulerAngles.z = .pi / 2
                tire.geometry?.firstMaterial = black
                rolling.addChildNode(tire)

                let hub = SCNNode(geometry: SCNCylinder(radius: 0.30, height: 0.35))
                hub.eulerAngles.z = .pi / 2
                hub.geometry?.firstMaterial = steel
                rolling.addChildNode(hub)
                for spoke in 0..<6 {
                    let spokeNode = box(0.07, 0.41, 0.045, at: side * 0.188, 0, 0,
                                        material: black, bevel: 0.012, parent: rolling)
                    spokeNode.eulerAngles.x = Float(spoke) * .pi / 3
                }
                car.addChildNode(pivot)
                wheels.append(pivot)
            }
        }

        var flames: [SCNNode] = []
        for side: Float in [-1,1] {
            let pipe = SCNNode(geometry: SCNTorus(ringRadius: 0.135, pipeRadius: 0.035))
            pipe.position = SCNVector3(side * 0.54, 0.65, 2.42)
            pipe.geometry?.firstMaterial = steel
            car.addChildNode(pipe)

            let flame = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.15, height: 1.35))
            flame.position = SCNVector3(side * 0.54, 0.66, 2.87)
            flame.eulerAngles.x = .pi / 2
            flame.geometry?.firstMaterial = orange
            flame.isHidden = true
            car.addChildNode(flame)
            flames.append(flame)
        }

        let headlight = SCNLight()
        headlight.type = .spot
        headlight.intensity = 900
        headlight.spotInnerAngle = 18
        headlight.spotOuterAngle = 48
        headlight.attenuationStartDistance = 1
        headlight.attenuationEndDistance = 45
        headlight.color = UIColor(red: 0.7, green: 0.86, blue: 1, alpha: 1)
        let lamp = SCNNode()
        lamp.light = headlight
        lamp.position = SCNVector3(0, 1.05, -2.26)
        lamp.eulerAngles.x = -.pi / 2
        car.addChildNode(lamp)

        return Assembly(wheels: wheels, flames: flames)
    }

    static func mat(_ color: UIColor, metal: CGFloat, rough: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.metalness.contents = metal
        m.roughness.contents = rough
        m.lightingModel = .physicallyBased
        m.isDoubleSided = true
        return m
    }

    private static func emissive(_ color: UIColor, strength: CGFloat) -> SCNMaterial {
        let m = mat(color, metal: 0.15, rough: 0.25)
        m.emission.contents = color
        m.emission.intensity = strength
        return m
    }

    private static func polygons(_ vertices: [SCNVector3], indices: [Int32],
                                 material: SCNMaterial) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(vertices: vertices)
        var raw = Data()
        for var index in indices {
            withUnsafeBytes(of: &index) { raw.append(contentsOf: $0) }
        }
        let element = SCNGeometryElement(data: raw, primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        geometry.firstMaterial = material
        return geometry
    }
}
