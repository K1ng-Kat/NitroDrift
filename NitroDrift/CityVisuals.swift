import UIKit
import SceneKit

enum CityVisuals {
    private static func packagedMap(_ role: String) -> UIImage? {
        for ext in ["jpg", "png"] {
            if let url = Bundle.main.url(forResource: "asphalt_" + role,
                                         withExtension: ext,
                                         subdirectory: "Assets.scnassets/Surfaces"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }

    static func roadRoughness() -> Any { packagedMap("roughness") ?? 0.77 as Any }

    static func roadMaterial(horizontal: Bool = false) -> SCNMaterial {
        let image = texture(size: 256) { context, size in
            UIColor(red: 0.10, green: 0.105, blue: 0.125, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var seed: UInt32 = 0x9AE310
            func random() -> CGFloat {
                seed = 1664525 &* seed &+ 1013904223
                return CGFloat(seed % 10_000) / 10_000
            }
            for _ in 0..<13_000 {
                let brightness = 0.07 + random() * 0.20
                UIColor(white: brightness, alpha: 0.18 + random() * 0.22).setFill()
                let x = random() * size.width
                let y = random() * size.height
                context.fill(CGRect(x: x, y: y, width: 0.5 + random() * 1.7,
                                    height: 0.5 + random() * 1.4))
            }
            UIColor(white: 0.20, alpha: 0.10).setStroke()
            for _ in 0..<30 {
                context.move(to: CGPoint(x: random() * size.width, y: random() * size.height))
                context.addLine(to: CGPoint(x: random() * size.width, y: random() * size.height))
            }
            context.strokePath()
        }
        let mat = SCNMaterial()
        mat.diffuse.contents = packagedMap("diffuse") ?? image
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        // Physical texel scale should not change drastically with road
        // orientation. Long 1040 m strips repeat ~130 times down their length.
        let tiled = horizontal ? SCNMatrix4MakeScale(130, 3.0, 1)
                               : SCNMatrix4MakeScale(3.0, 130, 1)
        mat.diffuse.contentsTransform = tiled
        mat.normal.contentsTransform = tiled
        mat.roughness.contentsTransform = tiled
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.normal.wrapS = .repeat
        mat.normal.wrapT = .repeat
        mat.roughness.wrapS = .repeat
        mat.roughness.wrapT = .repeat
        mat.roughness.contents = packagedMap("roughness") ?? 0.77 as Any
        mat.normal.contents = packagedMap("normal") ?? cachedRoadNormals
        mat.normal.intensity = 0.45
        mat.metalness.contents = 0.03
        mat.lightingModel = .physicallyBased
        return mat
    }

    // Cached PBR normal maps. Small periodic sine derivatives produce seamless
    // tiled road microdetail without shipping copyrighted texture files.
    private static let cachedRoadNormals = makeNormalTexture(wet: false)
    private static let cachedWetNormals = makeNormalTexture(wet: true)

    static func roadNormalMap() -> UIImage { packagedMap("normal") ?? cachedRoadNormals }
    static func rainNormalMap() -> UIImage { packagedMap("normal") ?? cachedWetNormals }

    private static func makeNormalTexture(wet: Bool) -> UIImage {
        let side = 128
        let tau = Double.pi * 2
        func height(_ u: Double, _ v: Double) -> Double {
            let fine = sin(u * tau * 19) * cos(v * tau * 23)
            let grain = sin((u + v) * tau * 31) * cos((u - v) * tau * 17)
            if wet {
                return 0.45 * sin(u * tau * 7 + v * tau * 4) +
                       0.36 * sin(v * tau * 9 - u * tau * 3) + 0.18 * fine
            }
            return 0.32 * fine + 0.22 * grain
        }
        let delta = 1.0 / Double(side)
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let u = Double(x) / Double(side)
                let v = Double(y) / Double(side)
                let du = (height(u + delta, v) - height(u - delta, v)) * (wet ? 0.27 : 0.16)
                let dv = (height(u, v + delta) - height(u, v - delta)) * (wet ? 0.27 : 0.16)
                let length = sqrt(du * du + dv * dv + 1)
                let nx = -du / length, ny = -dv / length, nz = 1 / length
                let offset = (y * side + x) * 4
                bytes[offset] = UInt8(max(0, min(255, Int((nx * 0.5 + 0.5) * 255))))
                bytes[offset + 1] = UInt8(max(0, min(255, Int((ny * 0.5 + 0.5) * 255))))
                bytes[offset + 2] = UInt8(max(0, min(255, Int((nz * 0.5 + 0.5) * 255))))
                bytes[offset + 3] = 255
            }
        }
        let data = Data(bytes)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(width: side, height: side,
                            bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: side * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider,
                            decode: nil, shouldInterpolate: true,
                            intent: .defaultIntent)!
        return UIImage(cgImage: image)
    }

    static func sky() -> UIImage {
        return texture(size: 512) { context, size in
            let colors = [
                UIColor(red: 0.006, green: 0.011, blue: 0.038, alpha: 1).cgColor,
                UIColor(red: 0.035, green: 0.045, blue: 0.10, alpha: 1).cgColor,
                UIColor(red: 0.115, green: 0.09, blue: 0.16, alpha: 1).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray, locations: [0, 0.58, 1])!
            context.drawLinearGradient(gradient, start: .zero,
                                       end: CGPoint(x: 0, y: size.height), options: [])
            var seed: UInt32 = 0xACED0121
            func random() -> CGFloat {
                seed = 1664525 &* seed &+ 1013904223
                return CGFloat(seed % 10_000) / 10_000
            }
            for _ in 0..<110 {
                let px = random() * size.width
                let py = random() * size.height * 0.66
                UIColor(white: 0.88, alpha: 0.08 + random() * 0.50).setFill()
                context.fill(CGRect(x: px, y: py, width: 1, height: 1))
            }
        }
    }

    private static func texture(size: Int, render: (CGContext, CGSize) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
            .image { renderer in render(renderer.cgContext, CGSize(width: size, height: size)) }
    }
}
