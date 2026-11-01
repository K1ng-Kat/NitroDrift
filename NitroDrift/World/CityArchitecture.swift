import SceneKit
import UIKit

/// Runtime-baked, physically based city facade atlases.
/// Windows are painted into a single textured face instead of producing
/// thousands of emissive box nodes. A separate emission texture gives each
/// building a varied, believable nighttime pattern.
enum CityArchitecture {
    struct Style {
        let walls: SCNMaterial
        let rooftop: SCNMaterial
        let trim: SCNMaterial
        let accent: SCNMaterial
    }

    static let presets: [Style] = (0..<6).map { createStyle(index: $0) }

    private static func createStyle(index: Int) -> Style {
        let textureSize = CGSize(width: 512, height: 768)
        let hueVariants: [(CGFloat, CGFloat, CGFloat)] = [
            (0.11, 0.14, 0.18), // limestone concrete
            (0.09, 0.13, 0.17), // blue steel glass
            (0.15, 0.14, 0.14), // warm masonry
            (0.10, 0.12, 0.12), // midnight aluminum
            (0.12, 0.12, 0.16), // charcoal
            (0.17, 0.15, 0.13)  // aged sandstone
        ]
        let channel = hueVariants[index]
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let emitterFormat = UIGraphicsImageRendererFormat()
        emitterFormat.opaque = false
        emitterFormat.scale = 1
        let cols = index.isMultiple(of: 3) ? 8 : 10
        let floors = index.isMultiple(of: 2) ? 15 : 18
        let unitX = textureSize.width / CGFloat(cols)
        let unitY = textureSize.height / CGFloat(floors)
        var seed = UInt64(23_781 + index * 97_013)
        func random() -> CGFloat {
            seed = 2862933555777941757 &* seed &+ 3037000493
            return CGFloat((seed >> 33) % 10000) / 10000
        }
        var windows: [(CGRect, UIColor, CGFloat)] = []
        for row in 0..<floors {
            for col in 0..<cols {
                // Leave occasional masonry / service cores rather than
                // repeating a perfectly uniform illuminated grid.
                if ((col + row * 2 + index) % 31) == 0 { continue }
                let padX = unitX * (index == 1 ? 0.12 : 0.19)
                let padY = unitY * (index == 3 ? 0.12 : 0.23)
                let rect = CGRect(x: CGFloat(col) * unitX + padX,
                                  y: CGFloat(row) * unitY + padY,
                                  width: unitX - padX * 2,
                                  height: unitY - padY * 2)
                let lit = random() < (index == 4 ? 0.39 : 0.54)
                let warm = random() < 0.62
                let color = lit
                    ? (warm ? UIColor(red: 1, green: 0.69 + random() * 0.12,
                                      blue: 0.35 + random() * 0.1, alpha: 1)
                            : UIColor(red: 0.65 + random() * 0.13,
                                      green: 0.78, blue: 1, alpha: 1))
                    : UIColor(red: 0.035 + random() * 0.07,
                              green: 0.072 + random() * 0.07,
                              blue: 0.11 + random() * 0.06, alpha: 1)
                windows.append((rect, color, lit ? 0.55 + random() * 0.35 : 0))
            }
        }

        let facade = UIGraphicsImageRenderer(size: textureSize, format: format).image { renderer in
            let context = renderer.cgContext
            UIColor(red: channel.0, green: channel.1, blue: channel.2, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: textureSize))
            // Finely varied vertical surface texture, columns and floor joints.
            for _ in 0..<920 {
                let x = random() * textureSize.width
                let y = random() * textureSize.height
                UIColor(white: random() > 0.5 ? 1 : 0, alpha: 0.03 + random() * 0.04).setFill()
                context.fill(CGRect(x: x, y: y, width: 0.4 + random() * 1.2,
                                    height: 3 + random() * 18))
            }
            for row in 0..<floors {
                let y = CGFloat(row) * unitY
                UIColor(white: 0.03, alpha: 0.26).setFill()
                context.fill(CGRect(x: 0, y: y, width: textureSize.width, height: 2.2))
                UIColor(white: 0.55, alpha: 0.11).setFill()
                context.fill(CGRect(x: 0, y: y + 2.2, width: textureSize.width, height: 1.3))
            }
            for col in 0..<cols {
                let x = CGFloat(col) * unitX
                UIColor(white: 0.01, alpha: 0.17).setFill()
                context.fill(CGRect(x: x, y: 0, width: 2, height: textureSize.height))
            }
            for (rect, light, _) in windows {
                // Recessed windows: shadowed lintel and a thin aluminum frame.
                UIColor.black.withAlphaComponent(0.62).setFill()
                context.fill(rect.insetBy(dx: -2.3, dy: -2.1))
                UIColor(red: 0.30, green: 0.36, blue: 0.40, alpha: 1).setFill()
                context.fill(rect.insetBy(dx: -1.0, dy: -1.0))
                light.withAlphaComponent(0.66).setFill()
                context.fill(rect)
                UIColor(red: 0.12, green: 0.17, blue: 0.22, alpha: 0.55).setFill()
                context.fill(CGRect(x: rect.midX - 1, y: rect.minY,
                                    width: 2, height: rect.height))
                UIColor.white.withAlphaComponent(0.07).setFill()
                context.fill(CGRect(x: rect.minX + 2, y: rect.minY + 2,
                                    width: 1.7, height: rect.height - 4))
            }
        }
        let emission = UIGraphicsImageRenderer(size: textureSize, format: emitterFormat).image { renderer in
            let context = renderer.cgContext
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: textureSize))
            for (rect, color, intensity) in windows where intensity > 0 {
                color.withAlphaComponent(intensity).setFill()
                context.fill(rect.insetBy(dx: 2, dy: 2))
            }
        }

        let walls = SCNMaterial()
        walls.lightingModel = .physicallyBased
        walls.diffuse.contents = facade
        walls.emission.contents = emission
        walls.emission.intensity = 0.38
        walls.roughness.contents = index == 1 || index == 3 ? 0.29 : 0.76
        walls.metalness.contents = index == 1 || index == 3 ? 0.34 : 0.09

        let roof = SCNMaterial()
        roof.lightingModel = .physicallyBased
        roof.diffuse.contents = UIColor(red: channel.0 * 0.72,
                                        green: channel.1 * 0.72,
                                        blue: channel.2 * 0.72, alpha: 1)
        roof.roughness.contents = 0.85

        let trim = SCNMaterial()
        trim.lightingModel = .physicallyBased
        trim.diffuse.contents = UIColor(red: 0.23, green: 0.25, blue: 0.29, alpha: 1)
        trim.metalness.contents = 0.62
        trim.roughness.contents = 0.30

        let accent = SCNMaterial()
        let tint = index.isMultiple(of: 2)
            ? UIColor(red: 0.55, green: 0.73, blue: 0.88, alpha: 1)
            : UIColor(red: 0.95, green: 0.72, blue: 0.48, alpha: 1)
        accent.diffuse.contents = tint
        accent.emission.contents = tint
        accent.emission.intensity = 0.76
        return Style(walls: walls, rooftop: roof, trim: trim, accent: accent)
    }

    /// SceneKit box face order: front, right, back, left, top, bottom.
    static func building(width: CGFloat, height: CGFloat, depth: CGFloat, index: Int) -> SCNNode {
        let preset = presets[abs(index) % presets.count]
        let bevel = min(0.20, max(0.035, width * 0.006))
        let mesh = SCNBox(width: width, height: height, length: depth, chamferRadius: bevel)
        mesh.materials = [
            preset.walls, preset.walls, preset.walls, preset.walls,
            preset.rooftop, preset.rooftop
        ]
        let node = SCNNode(geometry: mesh)
        node.castsShadow = true
        return node
    }
}
