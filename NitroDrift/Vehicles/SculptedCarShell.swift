import Foundation
import SceneKit
import simd

/// Mesh-based sports coupe shell. Replaces the cube-like primary body with a
/// lofted, smooth-shaded 3D silhouette. This is ORIGINAL procedural art, not a
/// scanned production car or a substitute for a professional USDZ vehicle.
enum SculptedCarShell {
    private struct Station {
        let z: Float
        let halfWidth: Float
        let bottom: Float
        let shoulder: Float
        let hood: Float
    }

    static func make(paint: SCNMaterial) -> SCNNode {
        let sections: [Station] = [
            .init(z: -2.39, halfWidth: 0.76, bottom: 0.49, shoulder: 0.75, hood: 0.79),
            .init(z: -2.27, halfWidth: 0.92, bottom: 0.44, shoulder: 0.84, hood: 0.98),
            .init(z: -1.92, halfWidth: 1.07, bottom: 0.43, shoulder: 0.98, hood: 1.09),
            .init(z: -1.47, halfWidth: 1.13, bottom: 0.42, shoulder: 1.05, hood: 1.20),
            .init(z: -0.73, halfWidth: 1.12, bottom: 0.42, shoulder: 1.06, hood: 1.24),
            .init(z:  0.36, halfWidth: 1.15, bottom: 0.43, shoulder: 1.05, hood: 1.22),
            .init(z:  1.24, halfWidth: 1.14, bottom: 0.43, shoulder: 1.02, hood: 1.17),
            .init(z:  1.82, halfWidth: 1.08, bottom: 0.44, shoulder: 0.99, hood: 1.08),
            .init(z:  2.23, halfWidth: 0.95, bottom: 0.47, shoulder: 0.82, hood: 0.92),
            .init(z:  2.36, halfWidth: 0.73, bottom: 0.50, shoulder: 0.72, hood: 0.78)
        ]

        let subdivisions = 32
        var positions: [SIMD3<Float>] = []
        for station in sections {
            for part in 0..<subdivisions {
                let theta = Float(part) / Float(subdivisions) * Float.pi * 2
                let c = cos(theta), si = sin(theta)
                let topAmplitude = station.hood - station.shoulder
                let bottomAmplitude = station.shoulder - station.bottom
                let y = station.shoulder + (si >= 0 ? topAmplitude * si : bottomAmplitude * si)
                // Fender bulges near the front/rear tires help eliminate the
                // dead-flat rectangle appearance along the door line.
                let fender = max(0, 1 - abs(abs(station.z) - 1.57) / 0.82)
                let width = station.halfWidth * (1 + fender * 0.025)
                positions.append(SIMD3<Float>(width * c, y, station.z))
            }
        }

        var indices: [Int32] = []
        for row in 0..<(sections.count - 1) {
            for column in 0..<subdivisions {
                let next = (column + 1) % subdivisions
                let a = Int32(row * subdivisions + column)
                let b = Int32(row * subdivisions + next)
                let c = Int32((row + 1) * subdivisions + column)
                let d = Int32((row + 1) * subdivisions + next)
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        // Per-vertex smooth normals (seamless around the circumference).
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(repeating: 0), count: positions.count)
        for t in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[t]), i1 = Int(indices[t + 1]), i2 = Int(indices[t + 2])
            let normal = simd_cross(positions[i1] - positions[i0], positions[i2] - positions[i0])
            normals[i0] += normal
            normals[i1] += normal
            normals[i2] += normal
        }
        let vertexNormals: [SCNVector3] = normals.enumerated().map { index, normal in
            let reference = positions[index]
            var n = simd_length(normal) > 0.00001
                ? simd_normalize(normal) : SIMD3<Float>(0, 1, 0)
            // Prevent flipped lighting even if the source ring's winding
            // changes when additional styling profiles are introduced.
            let fromCenter = SIMD3<Float>(reference.x, reference.y - 0.83, 0)
            if simd_dot(n, fromCenter) < 0 { n = -n }
            return SCNVector3(n.x, n.y, n.z)
        }

        var bytes = Data(capacity: indices.count * MemoryLayout<Int32>.size)
        for value in indices {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
        }
        let source = SCNGeometrySource(vertices: positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let normalSource = SCNGeometrySource(normals: vertexNormals)
        let faces = SCNGeometryElement(data: bytes, primitiveType: .triangles,
                                       primitiveCount: indices.count / 3,
                                       bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [source, normalSource], elements: [faces])
        geometry.materials = [paint]
        let node = SCNNode(geometry: geometry)
        node.name = "sculpted-paint-shell"
        return node
    }
}
